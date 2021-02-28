#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include "relay_tag_engine.h"

static TagDatabase g_default_tag_db;
static bool g_tag_db_initialized = false;

static int64_t current_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (int64_t)ts.tv_sec * 1000 + (ts.tv_nsec / 1000000);
}

void tag_db_init(TagDatabase *db) {
    db->count = 0;
    pthread_rwlock_init(&db->rwlock, NULL);
    for (size_t i = 0; i < RELAY_MAX_TAGS; ++i) {
        memset(&db->tags[i], 0, sizeof(Tag));
    }
}

void tag_db_free(TagDatabase *db) {
    pthread_rwlock_wrlock(&db->rwlock);
    db->count = 0;
    pthread_rwlock_unlock(&db->rwlock);
    pthread_rwlock_destroy(&db->rwlock);
}

int tag_db_register(TagDatabase *db, const char *name, TagType type, const char *units, double eu_min, double eu_max) {
    pthread_rwlock_wrlock(&db->rwlock);
    for (size_t i = 0; i < db->count; ++i) {
        if (strcmp(db->tags[i].name, name) == 0) {
            pthread_rwlock_unlock(&db->rwlock);
            return (int)i;
        }
    }
    if (db->count >= RELAY_MAX_TAGS) {
        pthread_rwlock_unlock(&db->rwlock);
        return -1;
    }
    int id = (int)db->count++;
    Tag *t = &db->tags[id];
    strncpy(t->name, name, RELAY_TAG_NAME_LEN - 1);
    t->name[RELAY_TAG_NAME_LEN - 1] = '\0';
    t->type = type;
    if (units) {
        strncpy(t->units, units, RELAY_TAG_UNIT_LEN - 1);
        t->units[RELAY_TAG_UNIT_LEN - 1] = '\0';
    }
    t->eu_min = eu_min;
    t->eu_max = eu_max;
    t->raw_min = 0.0;
    t->raw_max = 65535.0;
    t->quality = QUALITY_GOOD;
    t->timestamp_ms = current_time_ms();
    t->value = eu_min;
    t->last_emitted_val = eu_min;

    pthread_rwlock_unlock(&db->rwlock);
    return id;
}

int tag_db_find(TagDatabase *db, const char *name) {
    pthread_rwlock_rdlock(&db->rwlock);
    for (size_t i = 0; i < db->count; ++i) {
        if (strcmp(db->tags[i].name, name) == 0) {
            pthread_rwlock_unlock(&db->rwlock);
            return (int)i;
        }
    }
    pthread_rwlock_unlock(&db->rwlock);
    return -1;
}

bool tag_db_set_raw(TagDatabase *db, int tag_id, double raw) {
    pthread_rwlock_wrlock(&db->rwlock);
    if (tag_id < 0 || (size_t)tag_id >= db->count) {
        pthread_rwlock_unlock(&db->rwlock);
        return false;
    }
    Tag *t = &db->tags[tag_id];
    t->raw_value = raw;

    /* Linear Engineering Units scaling */
    double span_raw = t->raw_max - t->raw_min;
    double span_eu = t->eu_max - t->eu_min;
    if (fabs(span_raw) > 1e-9) {
        double fraction = (raw - t->raw_min) / span_raw;
        t->value = t->eu_min + fraction * span_eu;
    } else {
        t->value = raw;
    }
    t->timestamp_ms = current_time_ms();
    pthread_rwlock_unlock(&db->rwlock);
    return true;
}

bool tag_db_set_eu(TagDatabase *db, int tag_id, double eu) {
    pthread_rwlock_wrlock(&db->rwlock);
    if (tag_id < 0 || (size_t)tag_id >= db->count) {
        pthread_rwlock_unlock(&db->rwlock);
        return false;
    }
    Tag *t = &db->tags[tag_id];
    t->value = eu;
    t->timestamp_ms = current_time_ms();
    pthread_rwlock_unlock(&db->rwlock);
    return true;
}

bool tag_db_set_discrete(TagDatabase *db, int tag_id, bool state) {
    pthread_rwlock_wrlock(&db->rwlock);
    if (tag_id < 0 || (size_t)tag_id >= db->count) {
        pthread_rwlock_unlock(&db->rwlock);
        return false;
    }
    Tag *t = &db->tags[tag_id];
    t->int_value = state ? 1 : 0;
    t->value = state ? 1.0 : 0.0;
    t->timestamp_ms = current_time_ms();
    pthread_rwlock_unlock(&db->rwlock);
    return true;
}

bool tag_db_set_quality(TagDatabase *db, int tag_id, TagQuality q) {
    pthread_rwlock_wrlock(&db->rwlock);
    if (tag_id < 0 || (size_t)tag_id >= db->count) {
        pthread_rwlock_unlock(&db->rwlock);
        return false;
    }
    db->tags[tag_id].quality = q;
    pthread_rwlock_unlock(&db->rwlock);
    return true;
}

double tag_db_get_eu(TagDatabase *db, int tag_id) {
    pthread_rwlock_rdlock(&db->rwlock);
    if (tag_id < 0 || (size_t)tag_id >= db->count) {
        pthread_rwlock_unlock(&db->rwlock);
        return 0.0;
    }
    double v = db->tags[tag_id].value;
    pthread_rwlock_unlock(&db->rwlock);
    return v;
}

bool tag_db_get_discrete(TagDatabase *db, int tag_id) {
    pthread_rwlock_rdlock(&db->rwlock);
    if (tag_id < 0 || (size_t)tag_id >= db->count) {
        pthread_rwlock_unlock(&db->rwlock);
        return false;
    }
    bool s = db->tags[tag_id].int_value != 0;
    pthread_rwlock_unlock(&db->rwlock);
    return s;
}

TagQuality tag_db_get_quality(TagDatabase *db, int tag_id) {
    pthread_rwlock_rdlock(&db->rwlock);
    if (tag_id < 0 || (size_t)tag_id >= db->count) {
        pthread_rwlock_unlock(&db->rwlock);
        return QUALITY_BAD_NONSPECIFIC;
    }
    TagQuality q = db->tags[tag_id].quality;
    pthread_rwlock_unlock(&db->rwlock);
    return q;
}

Tag tag_db_get_snapshot(TagDatabase *db, int tag_id) {
    Tag snapshot;
    memset(&snapshot, 0, sizeof(Tag));
    pthread_rwlock_rdlock(&db->rwlock);
    if (tag_id >= 0 && (size_t)tag_id < db->count) {
        memcpy(&snapshot, &db->tags[tag_id], sizeof(Tag));
    }
    pthread_rwlock_unlock(&db->rwlock);
    return snapshot;
}

TagDatabase *relay_global_tag_db(void) {
    if (!g_tag_db_initialized) {
        tag_db_init(&g_default_tag_db);
        g_tag_db_initialized = true;
    }
    return &g_default_tag_db;
}
