' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Pure BASIC Swinging Door Trending (SDT) Compression Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/historian/sdt_compress.bas
' ==============================================================================
'
' This module implements the swinging door trending (SDT) compression algorithm,
' the industry gold standard for time-series sensor compression (OSIsoft PI).
' Given an error tolerance epsilon, it projects upper and lower angle doors from
' the last recorded point (t0, y0). As new samples arrive, the doors swing inward.
' When the doors cross, the preceding point is emitted to permanent storage.
' ==============================================================================

' SdtCompressSample: Processes single incoming sensor sample (timeMs, val)
' Returns: 1 if an archive point was emitted to storage, 0 otherwise
FUNCTION SdtCompressSample(rec AS SdtCompressorRecord, currentClockMs AS DOUBLE, _
                           currentVal AS DOUBLE, emittedTimeMs AS DOUBLE, _
                           emittedVal AS DOUBLE) AS INTEGER
    rec.TotalRawPoints = rec.TotalRawPoints + 1.0

    ' 1. Establish initial origin point if first sample
    IF rec.HasFirstPoint = 0 THEN
        rec.HasFirstPoint = 1
        rec.LastArchivedTime = currentClockMs
        rec.LastArchivedVal = currentVal
        rec.PrevSampleTime = currentClockMs
        rec.PrevSampleVal = currentVal
        rec.SlopeUpper = 1.0E30
        rec.SlopeLower = -1.0E30

        ' First point is always archived
        rec.TotalSavedPoints = rec.TotalSavedPoints + 1.0
        emittedTimeMs = currentClockMs
        emittedVal = currentVal
        RETURN 1
    END IF

    ' 2. Check boxcar minimum time interval
    DIM dtMs AS DOUBLE : dtMs = currentClockMs - rec.LastArchivedTime
    IF dtMs < rec.MinIntervalMs THEN
        rec.PrevSampleTime = currentClockMs
        rec.PrevSampleVal = currentVal
        RETURN 0
    END IF

    ' 3. Check forced maximum recording interval
    IF dtMs >= rec.MaxIntervalMs THEN
        ' Emit preceding point if distinct from origin
        IF rec.PrevSampleTime > rec.LastArchivedTime THEN
            emittedTimeMs = rec.PrevSampleTime
            emittedVal = rec.PrevSampleVal
            rec.TotalSavedPoints = rec.TotalSavedPoints + 1.0

            rec.LastArchivedTime = rec.PrevSampleTime
            rec.LastArchivedVal = rec.PrevSampleVal
            rec.PrevSampleTime = currentClockMs
            rec.PrevSampleVal = currentVal
            rec.SlopeUpper = 1.0E30
            rec.SlopeLower = -1.0E30
            RETURN 1
        END IF
    END IF

    ' 4. Compute slope constraints to current point
    DIM dtSec AS DOUBLE : dtSec = dtMs / 1000.0
    IF dtSec < 1.0E-6 THEN dtSec = 1.0E-6

    DIM sUpper AS DOUBLE
    sUpper = (currentVal - rec.LastArchivedVal + rec.CompTolerance) / dtSec
    DIM sLower AS DOUBLE
    sLower = (currentVal - rec.LastArchivedVal - rec.CompTolerance) / dtSec

    ' Doors swing inward (Upper slope decreases, Lower slope increases)
    IF sUpper < rec.SlopeUpper THEN rec.SlopeUpper = sUpper
    IF sLower > rec.SlopeLower THEN rec.SlopeLower = sLower

    ' 5. Check if doors have crossed!
    IF rec.SlopeUpper < rec.SlopeLower THEN
        ' Doors crossed! Preceding point must be archived
        emittedTimeMs = rec.PrevSampleTime
        emittedVal = rec.PrevSampleVal
        rec.TotalSavedPoints = rec.TotalSavedPoints + 1.0

        ' Establish preceding point as new origin
        rec.LastArchivedTime = rec.PrevSampleTime
        rec.LastArchivedVal = rec.PrevSampleVal

        ' Recalculate door slopes from new origin to current point
        DIM newDtMs AS DOUBLE : newDtMs = currentClockMs - rec.LastArchivedTime
        DIM newDtSec AS DOUBLE : newDtSec = newDtMs / 1000.0
        IF newDtSec < 1.0E-6 THEN newDtSec = 1.0E-6

        rec.SlopeUpper = (currentVal - rec.LastArchivedVal + rec.CompTolerance) / newDtSec
        rec.SlopeLower = (currentVal - rec.LastArchivedVal - rec.CompTolerance) / newDtSec

        rec.PrevSampleTime = currentClockMs
        rec.PrevSampleVal = currentVal
        RETURN 1
    END IF

    rec.PrevSampleTime = currentClockMs
    rec.PrevSampleVal = currentVal
    RETURN 0
END FUNCTION

' GetSdtCompressionRatio: Calculates percentage of bandwidth/storage saved
FUNCTION GetSdtCompressionRatio(rec AS SdtCompressorRecord) AS DOUBLE
    IF rec.TotalRawPoints <= 0.0 THEN RETURN 0.0
    DIM savedFraction AS DOUBLE
    savedFraction = 1.0 - (rec.TotalSavedPoints / rec.TotalRawPoints)
    RETURN savedFraction * 100.0
END FUNCTION
