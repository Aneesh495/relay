' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Historical Query Engine & Time-Slice Interpolation
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/historian/query_engine.bas
' ==============================================================================
'
' This module implements query interpolation and downsampling. It enables
' operator consoles to retrieve reconstructed process curves at arbitrary
' timestamps using either linear interpolation or step (sample-and-hold) modes.
' ==============================================================================

CONST INTERP_MODE_LINEAR = 0
CONST INTERP_MODE_STEP   = 1

' InterpolateHistoricalValue: Reconstructs value at arbitrary query timestamp tTargetMs
FUNCTION InterpolateHistoricalValue(times(1024) AS DOUBLE, values(1024) AS DOUBLE, _
                                    count AS INTEGER, tTargetMs AS DOUBLE, interpMode AS INTEGER) AS DOUBLE
    IF count <= 0 THEN RETURN 0.0
    IF count = 1 OR tTargetMs <= times(0) THEN RETURN values(0)
    IF tTargetMs >= times(count - 1) THEN RETURN values(count - 1)

    ' Binary or sequential bracket search
    DIM i AS INTEGER
    FOR i = 0 TO count - 2
        IF tTargetMs >= times(i) AND tTargetMs <= times(i + 1) THEN
            DIM t0 AS DOUBLE : t0 = times(i)
            DIM t1 AS DOUBLE : t1 = times(i + 1)
            DIM y0 AS DOUBLE : y0 = values(i)
            DIM y1 AS DOUBLE : y1 = values(i + 1)

            IF interpMode = INTERP_MODE_STEP THEN
                ' Step mode: zero-order hold (sample and hold y0)
                RETURN y0
            ELSE
                ' Linear mode: first-order slope interpolation
                DIM dt AS DOUBLE : dt = t1 - t0
                IF dt > 0.0 THEN
                    DIM alpha AS DOUBLE : alpha = (tTargetMs - t0) / dt
                    RETURN y0 + alpha * (y1 - y0)
                ELSE
                    RETURN y0
                END IF
            END IF
        END IF
    NEXT i

    RETURN values(count - 1)
END FUNCTION

' DownsampleHistoricalSeries: Resamples series into N uniform time-slice buckets
SUB DownsampleHistoricalSeries(inTimes(1024) AS DOUBLE, inValues(1024) AS DOUBLE, inCount AS INTEGER, _
                               tStartMs AS DOUBLE, tEndMs AS DOUBLE, bucketCount AS INTEGER, _
                               outTimes(128) AS DOUBLE, outValues(128) AS DOUBLE)
    IF bucketCount > 128 THEN bucketCount = 128
    IF bucketCount < 2 OR tEndMs <= tStartMs THEN EXIT SUB

    DIM stepMs AS DOUBLE
    stepMs = (tEndMs - tStartMs) / (bucketCount - 1)

    DIM b AS INTEGER
    FOR b = 0 TO bucketCount - 1
        DIM queryTime AS DOUBLE : queryTime = tStartMs + b * stepMs
        outTimes(b) = queryTime
        outValues(b) = InterpolateHistoricalValue(inTimes, inValues, inCount, queryTime, INTERP_MODE_LINEAR)
    NEXT b
END SUB
