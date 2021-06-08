' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Time-Weighted Aggregations & Numerical Integration
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/historian/aggregations.bas
' ==============================================================================
'
' This module implements Time-Weighted Averages (TWA) and numerical totalization.
' Because industrial historians use Swinging Door compression, samples arrive
' with irregular timestamps. Calculating arithmetic averages on compressed data
' introduces massive distortion. Time-weighting guarantees true mathematical accuracy.
' ==============================================================================

' ComputeTimeWeightedAverage: Calculates TWA over arbitrary time window [tStartMs, tEndMs]
FUNCTION ComputeTimeWeightedAverage(times(1024) AS DOUBLE, values(1024) AS DOUBLE, _
                                   count AS INTEGER, tStartMs AS DOUBLE, tEndMs AS DOUBLE) AS DOUBLE
    IF count < 1 OR tEndMs <= tStartMs THEN RETURN 0.0
    IF count = 1 THEN RETURN values(0)

    DIM totalArea AS DOUBLE : totalArea = 0.0
    DIM totalTime AS DOUBLE : totalTime = 0.0
    DIM i AS INTEGER

    FOR i = 0 TO count - 2
        DIM t0 AS DOUBLE : t0 = times(i)
        DIM t1 AS DOUBLE : t1 = times(i + 1)
        DIM y0 AS DOUBLE : y0 = values(i)
        DIM y1 AS DOUBLE : y1 = values(i + 1)

        ' Check overlap with query window
        IF t1 >= tStartMs AND t0 <= tEndMs THEN
            DIM segStart AS DOUBLE : segStart = t0 < tStartMs ? tStartMs : t0
            DIM segEnd AS DOUBLE : segEnd = t1 > tEndMs ? tEndMs : t1

            IF segEnd > segStart THEN
                DIM dt AS DOUBLE : dt = segEnd - segStart
                ' Linear interpolation for trapezoid height at segment boundaries
                DIM yAvg AS DOUBLE : yAvg = (y0 + y1) * 0.5
                totalArea = totalArea + yAvg * dt
                totalTime = totalTime + dt
            END IF
        END IF
    NEXT i

    IF totalTime > 0.0 THEN
        RETURN totalArea / totalTime
    END IF
    RETURN 0.0
END FUNCTION

' ComputeTrapezoidalTotalizer: Integrates instantaneous rate (units/hour) into total units
FUNCTION ComputeTrapezoidalTotalizer(times(1024) AS DOUBLE, ratesPerHour(1024) AS DOUBLE, _
                                     count AS INTEGER, tStartMs AS DOUBLE, tEndMs AS DOUBLE) AS DOUBLE
    IF count < 2 OR tEndMs <= tStartMs THEN RETURN 0.0

    DIM totalAccumulated AS DOUBLE : totalAccumulated = 0.0
    DIM i AS INTEGER

    FOR i = 0 TO count - 2
        DIM t0 AS DOUBLE : t0 = times(i)
        DIM t1 AS DOUBLE : t1 = times(i + 1)
        DIM r0 AS DOUBLE : r0 = ratesPerHour(i)
        DIM r1 AS DOUBLE : r1 = ratesPerHour(i + 1)

        IF t1 >= tStartMs AND t0 <= tEndMs THEN
            DIM segStart AS DOUBLE : segStart = t0 < tStartMs ? tStartMs : t0
            DIM segEnd AS DOUBLE : segEnd = t1 > tEndMs ? tEndMs : t1

            IF segEnd > segStart THEN
                DIM dtHours AS DOUBLE : dtHours = (segEnd - segStart) / 3600000.0
                DIM rAvg AS DOUBLE : rAvg = (r0 + r1) * 0.5
                totalAccumulated = totalAccumulated + rAvg * dtHours
            END IF
        END IF
    NEXT i

    RETURN totalAccumulated
END FUNCTION
