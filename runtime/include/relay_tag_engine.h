#ifndef RELAY_TAG_ENGINE_H
#define RELAY_TAG_ENGINE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <pthread.h>

#define RELAY_MAX_TAGS 8192
#define RELAY_TAG_NAME_LEN 64
#define RELAY_TAG_UNIT_LEN 32
#define RELAY_TAG_DESC_LEN 128

typedef enum {
    TAG_AI = 0,    /* Analog Input */
    TAG_AO,        /* Analog Output */
    TAG_DI,        /* Discrete Input */
    TAG_DO,        /* Discrete Output */
    TAG_CALC,      /* Calculated Tag */
    TAG_STR        /* String Tag */
} TagType;

typedef enum {
    QUALITY_BAD_NONSPECIFIC = 0,
    QUALITY_BAD_COMM_FAIL   = 24,
    QUALITY_BAD_SENSOR_FAIL = 8,
    QUALITY_UNCERTAIN       = 64,
    QUALITY_MANUAL_OVERRIDE = 96,
    QUALITY_GOOD            = 192
} TagQuality;

typedef struct {
    char name[RELAY_TAG_NAME_LEN];
    char description[RELAY_TAG_DESC_LEN];
    char units[RELAY_TAG_UNIT_LEN];
    TagType type;
    TagQuality quality;

    double value;
    int64_t int_value;
    char str_value[128];

    double raw_value;
    double raw_min;
    double raw_max;
    double eu_min;
    double eu_max;

    double deadband_abs;
    double deadband_pct;
    double last_emitted_val;

    int64_t timestamp_ms;
    bool is_simulated;
    bool is_locked;
} Tag;

typedef struct {
    Tag tags[RELAY_MAX_TAGS];
    size_t count;
    pthread_rwlock_t rwlock;
} TagDatabase;

void tag_db_init(TagDatabase *db);
void tag_db_free(TagDatabase *db);

int tag_db_register(TagDatabase *db, const char *name, TagType type, const char *units, double eu_min, double eu_max);
int tag_db_find(TagDatabase *db, const char *name);

bool tag_db_set_raw(TagDatabase *db, int tag_id, double raw);
bool tag_db_set_eu(TagDatabase *db, int tag_id, double eu);
bool tag_db_set_discrete(TagDatabase *db, int tag_id, bool state);
bool tag_db_set_quality(TagDatabase *db, int tag_id, TagQuality q);

double tag_db_get_eu(TagDatabase *db, int tag_id);
bool tag_db_get_discrete(TagDatabase *db, int tag_id);
TagQuality tag_db_get_quality(TagDatabase *db, int tag_id);
Tag tag_db_get_snapshot(TagDatabase *db, int tag_id);

/* Global Singleton Instance for Host Execution */
TagDatabase *relay_global_tag_db(void);

#endif /* RELAY_TAG_ENGINE_H */
