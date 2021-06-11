' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Write-Ahead Log (WAL) Serialization & CSV Telemetry Export
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/historian/wal_export.bas
' ==============================================================================
'
' This module implements telemetry record serialization for write-ahead logging
' and CSV export to enterprise data lakes.
' ==============================================================================

' FormatTelemetryCsvLine: Generates standard CSV line: timestamp,tagName,val,quality
FUNCTION FormatTelemetryCsvLine(timestampMs AS DOUBLE, tagName AS STRING, val AS DOUBLE, qualityCode AS INTEGER) AS STRING
    DIM sTs AS STRING : sTs = STR$(INT(timestampMs))
    DIM sVal AS STRING : sVal = FormatDouble(val, 4)
    DIM sQ AS STRING : sQ = STR$(qualityCode)
    RETURN sTs + "," + tagName + "," + sVal + "," + sQ
END FUNCTION

' FormatWalBinaryHexRecord: Generates 20-byte binary hex WAL frame
FUNCTION FormatWalBinaryHexRecord(timestampMs AS DOUBLE, seriesId AS INTEGER, val AS DOUBLE, qualityCode AS INTEGER) AS STRING
    DIM hexTs AS STRING : hexTs = WordToHex(INT(timestampMs \ 65536)) + WordToHex(INT(timestampMs) AND 65535)
    DIM hexSid AS STRING : hexSid = WordToHex(seriesId)
    DIM hexQ AS STRING : hexQ = WordToHex(qualityCode)
    RETURN hexTs + hexSid + hexQ
END FUNCTION
