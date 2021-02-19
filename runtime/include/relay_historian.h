#ifndef RELAY_HISTORIAN_H
#define RELAY_HISTORIAN_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "relay_tag_engine.h"

#define RELAY_HIST_BUFFER_SIZE 2048
#define RELAY_HIST_MAX_SERIES 32

typedef struct {
    int64_t timestamp_ms;
    double value;
    TagQuality quality;
} DataPoint;

typedef struct {
    int tag_id;
    double compression_dev;    /* Epsilon tolerance in engineering units */
    int64_t min_interval_ms;   /* Boxcar minimum time delta */
    int64_t max_interval_ms;   /* Forced emission interval */

    DataPoint last_archived;   /* (t0, y0) point */
    DataPoint prev_point;      /* (t_prev, y_prev) point */
    bool has_point;

    double slope_upper;        /* Maximum upper allowable slope */
    double slope_lower;        /* Minimum lower allowable slope */

    uint64_t raw_count;
    uint64_t archived_count;
} SdtCompressor;

typedef struct {
    DataPoint samples[RELAY_HIST_BUFFER_SIZE];
    size_t head;
    size_t tail;
    size_t count;
    pthread_mutex_t mutex;
} RingBuffer;

typedef struct {
    RingBuffer buffers[RELAY_HIST_MAX_SERIES];
    SdtCompressor compressors[RELAY_HIST_MAX_SERIES];
    size_t series_count;
    char wal_path[256];
    int wal_fd;
} Historian;

void historian_init(Historian *hist, const char *wal_file);
void historian_free(Historian *hist);

int historian_add_series(Historian *hist, int tag_id, double comp_dev, int64_t min_ms, int64_t max_ms);
bool historian_ingest(Historian *hist, int series_id, int64_t timestamp_ms, double val, TagQuality q);

/* Aggregations */
double historian_time_weighted_average(Historian *hist, int series_id, int64_t start_ms, int64_t end_ms);
double historian_trapezoidal_total(Historian *hist, int series_id, int64_t start_ms, int64_t end_ms);
bool historian_query_range(Historian *hist, int series_id, int64_t start_ms, int64_t end_ms,
                           DataPoint *out_points, size_t max_points, size_t *actual_points);

Historian *relay_global_historian(void);

#endif /* RELAY_HISTORIAN_H */
