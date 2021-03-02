#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include "relay_historian.h"

static Historian g_default_historian;
static bool g_historian_initialized = false;

void historian_init(Historian *hist, const char *wal_file) {
    hist->series_count = 0;
    hist->wal_fd = -1;
    if (wal_file && strlen(wal_file) > 0) {
        strncpy(hist->wal_path, wal_file, sizeof(hist->wal_path) - 1);
        hist->wal_fd = open(wal_file, O_CREAT | O_WRONLY | O_APPEND, 0644);
    } else {
        hist->wal_path[0] = '\0';
    }

    for (size_t i = 0; i < RELAY_HIST_MAX_SERIES; ++i) {
        pthread_mutex_init(&hist->buffers[i].mutex, NULL);
        hist->buffers[i].head = 0;
        hist->buffers[i].tail = 0;
        hist->buffers[i].count = 0;

        hist->compressors[i].has_point = false;
        hist->compressors[i].raw_count = 0;
        hist->compressors[i].archived_count = 0;
    }
}

void historian_free(Historian *hist) {
    for (size_t i = 0; i < RELAY_HIST_MAX_SERIES; ++i) {
        pthread_mutex_destroy(&hist->buffers[i].mutex);
    }
    if (hist->wal_fd >= 0) {
        close(hist->wal_fd);
        hist->wal_fd = -1;
    }
}

int historian_add_series(Historian *hist, int tag_id, double comp_dev, int64_t min_ms, int64_t max_ms) {
    if (hist->series_count >= RELAY_HIST_MAX_SERIES) {
        return -1;
    }
    int id = (int)hist->series_count++;
    SdtCompressor *c = &hist->compressors[id];
    c->tag_id = tag_id;
    c->compression_dev = comp_dev > 0.0 ? comp_dev : 0.01;
    c->min_interval_ms = min_ms > 0 ? min_ms : 10;
    c->max_interval_ms = max_ms > 0 ? max_ms : 60000;
    c->has_point = false;
    c->raw_count = 0;
    c->archived_count = 0;
    return id;
}

static void archive_point(Historian *hist, int series_id, DataPoint pt) {
    RingBuffer *rb = &hist->buffers[series_id];
    pthread_mutex_lock(&rb->mutex);

    rb->samples[rb->head] = pt;
    rb->head = (rb->head + 1) % RELAY_HIST_BUFFER_SIZE;
    if (rb->count < RELAY_HIST_BUFFER_SIZE) {
        rb->count++;
    } else {
        rb->tail = (rb->tail + 1) % RELAY_HIST_BUFFER_SIZE;
    }

    pthread_mutex_unlock(&rb->mutex);

    hist->compressors[series_id].archived_count++;

    /* Write-Ahead Log binary entry: 8 bytes timestamp, 8 bytes double, 2 bytes quality, 2 bytes series */
    if (hist->wal_fd >= 0) {
        uint8_t record[20];
        memcpy(&record[0], &pt.timestamp_ms, 8);
        memcpy(&record[8], &pt.value, 8);
        uint16_t q = (uint16_t)pt.quality;
        uint16_t s = (uint16_t)series_id;
        memcpy(&record[16], &q, 2);
        memcpy(&record[18], &s, 2);
        write(hist->wal_fd, record, sizeof(record));
    }
}

bool historian_ingest(Historian *hist, int series_id, int64_t timestamp_ms, double val, TagQuality q) {
    if (series_id < 0 || (size_t)series_id >= hist->series_count) {
        return false;
    }

    SdtCompressor *c = &hist->compressors[series_id];
    c->raw_count++;

    DataPoint curr = {timestamp_ms, val, q};

    if (!c->has_point) {
        /* First point ever: archive immediately and set as origin */
        c->last_archived = curr;
        c->prev_point = curr;
        c->has_point = true;
        c->slope_upper = 1e30;
        c->slope_lower = -1e30;
        archive_point(hist, series_id, curr);
        return true;
    }

    int64_t dt = curr.timestamp_ms - c->last_archived.timestamp_ms;
    if (dt < c->min_interval_ms) {
        /* Filter out chatter within boxcar window */
        c->prev_point = curr;
        return true;
    }

    /* Force archive if maximum elapsed time reached */
    if (dt >= c->max_interval_ms) {
        if (c->prev_point.timestamp_ms > c->last_archived.timestamp_ms) {
            archive_point(hist, series_id, c->prev_point);
        }
        archive_point(hist, series_id, curr);
        c->last_archived = curr;
        c->prev_point = curr;
        c->slope_upper = 1e30;
        c->slope_lower = -1e30;
        return true;
    }

    /* Compute slopes to current point */
    double dt_sec = (double)dt / 1000.0;
    if (dt_sec < 1e-6) dt_sec = 1e-6;

    double s_upper = (curr.value - c->last_archived.value + c->compression_dev) / dt_sec;
    double s_lower = (curr.value - c->last_archived.value - c->compression_dev) / dt_sec;

    /* Update swinging door constraints */
    if (s_upper < c->slope_upper) {
        c->slope_upper = s_upper;
    }
    if (s_lower > c->slope_lower) {
        c->slope_lower = s_lower;
    }

    /* Check if doors have crossed */
    if (c->slope_upper < c->slope_lower) {
        /* Doors crossed: archive the preceding point */
        if (c->prev_point.timestamp_ms > c->last_archived.timestamp_ms) {
            archive_point(hist, series_id, c->prev_point);
            c->last_archived = c->prev_point;
        }

        /* Recalculate slopes from new origin to current point */
        dt = curr.timestamp_ms - c->last_archived.timestamp_ms;
        dt_sec = (double)dt / 1000.0;
        if (dt_sec < 1e-6) dt_sec = 1e-6;

        c->slope_upper = (curr.value - c->last_archived.value + c->compression_dev) / dt_sec;
        c->slope_lower = (curr.value - c->last_archived.value - c->compression_dev) / dt_sec;
    }

    c->prev_point = curr;
    return true;
}

double historian_time_weighted_average(Historian *hist, int series_id, int64_t start_ms, int64_t end_ms) {
    if (series_id < 0 || (size_t)series_id >= hist->series_count || end_ms <= start_ms) {
        return 0.0;
    }

    RingBuffer *rb = &hist->buffers[series_id];
    pthread_mutex_lock(&rb->mutex);

    double total_area = 0.0;
    int64_t total_time = 0;

    if (rb->count < 2) {
        double v = rb->count == 1 ? rb->samples[rb->tail].value : 0.0;
        pthread_mutex_unlock(&rb->mutex);
        return v;
    }

    for (size_t i = 0; i < rb->count - 1; ++i) {
        size_t idx0 = (rb->tail + i) % RELAY_HIST_BUFFER_SIZE;
        size_t idx1 = (rb->tail + i + 1) % RELAY_HIST_BUFFER_SIZE;

        DataPoint p0 = rb->samples[idx0];
        DataPoint p1 = rb->samples[idx1];

        if (p1.timestamp_ms < start_ms || p0.timestamp_ms > end_ms) {
            continue;
        }

        int64_t t_start = p0.timestamp_ms < start_ms ? start_ms : p0.timestamp_ms;
        int64_t t_end = p1.timestamp_ms > end_ms ? end_ms : p1.timestamp_ms;

        if (t_end > t_start) {
            int64_t dt = t_end - t_start;
            /* Linear trapezoidal interpolation */
            double y_avg = (p0.value + p1.value) * 0.5;
            total_area += y_avg * dt;
            total_time += dt;
        }
    }

    pthread_mutex_unlock(&rb->mutex);

    if (total_time > 0) {
        return total_area / (double)total_time;
    }
    return 0.0;
}

double historian_trapezoidal_total(Historian *hist, int series_id, int64_t start_ms, int64_t end_ms) {
    if (series_id < 0 || (size_t)series_id >= hist->series_count || end_ms <= start_ms) {
        return 0.0;
    }

    RingBuffer *rb = &hist->buffers[series_id];
    pthread_mutex_lock(&rb->mutex);

    double total_integral = 0.0;

    for (size_t i = 0; i < rb->count - 1; ++i) {
        size_t idx0 = (rb->tail + i) % RELAY_HIST_BUFFER_SIZE;
        size_t idx1 = (rb->tail + i + 1) % RELAY_HIST_BUFFER_SIZE;

        DataPoint p0 = rb->samples[idx0];
        DataPoint p1 = rb->samples[idx1];

        if (p1.timestamp_ms < start_ms || p0.timestamp_ms > end_ms) {
            continue;
        }

        int64_t t_start = p0.timestamp_ms < start_ms ? start_ms : p0.timestamp_ms;
        int64_t t_end = p1.timestamp_ms > end_ms ? end_ms : p1.timestamp_ms;

        if (t_end > t_start) {
            double dt_hours = (double)(t_end - t_start) / 3600000.0;
            double y_avg = (p0.value + p1.value) * 0.5;
            total_integral += y_avg * dt_hours;
        }
    }

    pthread_mutex_unlock(&rb->mutex);
    return total_integral;
}

bool historian_query_range(Historian *hist, int series_id, int64_t start_ms, int64_t end_ms,
                           DataPoint *out_points, size_t max_points, size_t *actual_points) {
    if (!out_points || !actual_points || series_id < 0 || (size_t)series_id >= hist->series_count) {
        return false;
    }

    RingBuffer *rb = &hist->buffers[series_id];
    pthread_mutex_lock(&rb->mutex);

    size_t count = 0;
    for (size_t i = 0; i < rb->count; ++i) {
        size_t idx = (rb->tail + i) % RELAY_HIST_BUFFER_SIZE;
        DataPoint pt = rb->samples[idx];
        if (pt.timestamp_ms >= start_ms && pt.timestamp_ms <= end_ms) {
            if (count < max_points) {
                out_points[count++] = pt;
            } else {
                break;
            }
        }
    }

    *actual_points = count;
    pthread_mutex_unlock(&rb->mutex);
    return true;
}

Historian *relay_global_historian(void) {
    if (!g_historian_initialized) {
        historian_init(&g_default_historian, NULL);
        g_historian_initialized = true;
    }
    return &g_default_historian;
}
