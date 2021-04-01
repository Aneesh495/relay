' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' In-Memory Real-Time Tag Database Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/tags/tag_db.bas
' ==============================================================================
'
' This module implements the central in-memory tag registry for process points.
' It manages point allocation, name-based hashing and linear lookup, value reads,
' writes, and engineering units conversions.
' ==============================================================================

CONST MAX_TAG_REGISTRY_SIZE = 512

' TagTable: Global array storage for real-time process points
TYPE TagDatabaseTable
    Count AS INTEGER
    Tags(512) AS TagDefinition
END TYPE

' TagDbInit: Wipes and initializes the tag table
SUB TagDbInit(table AS TagDatabaseTable)
    table.Count = 0
    DIM i AS INTEGER
    FOR i = 0 TO MAX_TAG_REGISTRY_SIZE - 1
        table.Tags(i).TagId = -1
        table.Tags(i).TagName = ""
        table.Tags(i).TagType = 0
        table.Tags(i).Quality = QUALITY_BAD_NONSPECIFIC
        table.Tags(i).EuValue = 0.0
        table.Tags(i).RawValue = 0.0
        table.Tags(i).EuMin = 0.0
        table.Tags(i).EuMax = 100.0
        table.Tags(i).RawMin = 0.0
        table.Tags(i).RawMax = 65535.0
        table.Tags(i).DeadbandAbs = 0.1
        table.Tags(i).DeadbandPct = 0.1
        table.Tags(i).LastEmittedVal = 0.0
        table.Tags(i).TimestampMs = 0.0
        table.Tags(i).IsSimulated = 0
        table.Tags(i).IsClamped = 0
    NEXT i
END SUB

' TagDbRegister: Registers a new tag into the table and returns assigned TagId
FUNCTION TagDbRegister(table AS TagDatabaseTable, name AS STRING, tType AS INTEGER, minEu AS DOUBLE, maxEu AS DOUBLE) AS INTEGER
    ' Check if tag already registered
    DIM i AS INTEGER
    FOR i = 0 TO table.Count - 1
        IF table.Tags(i).TagName = name THEN
            RETURN i
        END IF
    NEXT i

    IF table.Count >= MAX_TAG_REGISTRY_SIZE THEN
        RETURN -1  ' Registry full
    END IF

    DIM newId AS INTEGER : newId = table.Count
    table.Count = table.Count + 1

    InitializeTagDefinition(table.Tags(newId), newId, name, tType, minEu, maxEu)
    RETURN newId
END FUNCTION

' TagDbFind: Looks up a tag by its ISA name string and returns its TagId
FUNCTION TagDbFind(table AS TagDatabaseTable, name AS STRING) AS INTEGER
    DIM i AS INTEGER
    FOR i = 0 TO table.Count - 1
        IF table.Tags(i).TagName = name THEN
            RETURN i
        END IF
    NEXT i
    RETURN -1
END FUNCTION

' TagDbWriteEu: Writes an engineering unit value to specified tag
FUNCTION TagDbWriteEu(table AS TagDatabaseTable, tagId AS INTEGER, val AS DOUBLE, timestampMs AS DOUBLE) AS INTEGER
    IF tagId < 0 OR tagId >= table.Count THEN
        RETURN 0
    END IF

    table.Tags(tagId).EuValue = val
    table.Tags(tagId).TimestampMs = timestampMs
    table.Tags(tagId).Quality = QUALITY_GOOD

    ' Check span clamping
    IF val < table.Tags(tagId).EuMin THEN
        table.Tags(tagId).IsClamped = 1
    ELSEIF val > table.Tags(tagId).EuMax THEN
        table.Tags(tagId).IsClamped = 1
    ELSE
        table.Tags(tagId).IsClamped = 0
    END IF

    RETURN 1
END FUNCTION

' TagDbReadEu: Reads current engineering unit value of specified tag
FUNCTION TagDbReadEu(table AS TagDatabaseTable, tagId AS INTEGER) AS DOUBLE
    IF tagId < 0 OR tagId >= table.Count THEN
        RETURN 0.0
    END IF
    RETURN table.Tags(tagId).EuValue
END FUNCTION

' TagDbGetQuality: Reads the quality status code of specified tag
FUNCTION TagDbGetQuality(table AS TagDatabaseTable, tagId AS INTEGER) AS INTEGER
    IF tagId < 0 OR tagId >= table.Count THEN
        RETURN QUALITY_BAD_NONSPECIFIC
    END IF
    RETURN table.Tags(tagId).Quality
END FUNCTION

' TagDbSetQuality: Overwrites the quality status code of specified tag
FUNCTION TagDbSetQuality(table AS TagDatabaseTable, tagId AS INTEGER, q AS INTEGER) AS INTEGER
    IF tagId < 0 OR tagId >= table.Count THEN
        RETURN 0
    END IF
    table.Tags(tagId).Quality = q
    RETURN 1
END FUNCTION
