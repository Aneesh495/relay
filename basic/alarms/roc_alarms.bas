' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Rate-of-Change (ROC) Alarm Calculation & Runaway Detection
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/alarms/roc_alarms.bas
' ==============================================================================
'
' This module implements rate-of-change (ROC) monitoring. It computes the time
' derivative dPV/dt over a sliding linear regression window to detect thermal
' runaway in reactors or explosive decompression in pressurized gas vessels.
' ==============================================================================

' RateOfChangeAlarmConfig: Configuration and state for ROC tracking
TYPE RateOfChangeAlarmConfig
    WindowSamples   AS INTEGER  ' Number of points in derivative regression (e.g., 10)
    MaxPositiveRoc  AS DOUBLE   ' Maximum allowed positive slope (EU per second)
    MaxNegativeRoc  AS DOUBLE   ' Maximum allowed negative slope (EU per second)
    HysteresisRoc   AS DOUBLE   ' Deadband for clearing alarm

    TimeHistory(32) AS DOUBLE   ' Timestamp array
    ValueHistory(32) AS DOUBLE  ' Value array
    SampleCount     AS INTEGER  ' Samples currently recorded in history

    CurrentRoc      AS DOUBLE   ' Calculated derivative dPV/dt
    IsPosRocActive  AS INTEGER  ' 1 if positive ROC alarm tripped
    IsNegRocActive  AS INTEGER  ' 1 if negative ROC alarm tripped
END TYPE

' InitializeRocAlarm: Configures rate-of-change monitor
SUB InitializeRocAlarm(cfg AS RateOfChangeAlarmConfig, windowSize AS INTEGER, maxPos AS DOUBLE, maxNeg AS DOUBLE, hyst AS DOUBLE)
    IF windowSize > 32 THEN windowSize = 32
    IF windowSize < 3 THEN windowSize = 3
    cfg.WindowSamples = windowSize
    cfg.MaxPositiveRoc = maxPos
    cfg.MaxNegativeRoc = ABS(maxNeg)
    cfg.HysteresisRoc = hyst > 0.0 ? hyst : 0.1
    cfg.SampleCount = 0
    cfg.CurrentRoc = 0.0
    cfg.IsPosRocActive = 0
    cfg.IsNegRocActive = 0
END SUB

' PushRocSample: Ingests new sample and calculates linear regression slope
SUB PushRocSample(cfg AS RateOfChangeAlarmConfig, currentVal AS DOUBLE, currentClockSec AS DOUBLE)
    ' Shift history window if full
    IF cfg.SampleCount < cfg.WindowSamples THEN
        cfg.TimeHistory(cfg.SampleCount) = currentClockSec
        cfg.ValueHistory(cfg.SampleCount) = currentVal
        cfg.SampleCount = cfg.SampleCount + 1
    ELSE
        DIM i AS INTEGER
        FOR i = 0 TO cfg.WindowSamples - 2
            cfg.TimeHistory(i) = cfg.TimeHistory(i + 1)
            cfg.ValueHistory(i) = cfg.ValueHistory(i + 1)
        NEXT i
        cfg.TimeHistory(cfg.WindowSamples - 1) = currentClockSec
        cfg.ValueHistory(cfg.WindowSamples - 1) = currentVal
    END IF

    IF cfg.SampleCount < 3 THEN
        cfg.CurrentRoc = 0.0
        EXIT SUB
    END IF

    ' Compute least-squares derivative slope dPV/dt
    DIM sumT AS DOUBLE : sumT = 0.0
    DIM sumV AS DOUBLE : sumV = 0.0
    DIM sumTV AS DOUBLE : sumTV = 0.0
    DIM sumT2 AS DOUBLE : sumT2 = 0.0
    DIM n AS INTEGER : n = cfg.SampleCount

    FOR i = 0 TO n - 1
        sumT = sumT + cfg.TimeHistory(i)
        sumV = sumV + cfg.ValueHistory(i)
        sumTV = sumTV + cfg.TimeHistory(i) * cfg.ValueHistory(i)
        sumT2 = sumT2 + cfg.TimeHistory(i) * cfg.TimeHistory(i)
    NEXT i

    DIM denom AS DOUBLE : denom = n * sumT2 - sumT * sumT
    IF ABS(denom) > 1.0E-9 THEN
        cfg.CurrentRoc = (n * sumTV - sumT * sumV) / denom
    ELSE
        cfg.CurrentRoc = 0.0
    END IF

    ' Evaluate Positive ROC Alarm with Hysteresis
    IF cfg.IsPosRocActive = 0 THEN
        IF cfg.CurrentRoc >= cfg.MaxPositiveRoc THEN cfg.IsPosRocActive = 1
    ELSE
        IF cfg.CurrentRoc <= (cfg.MaxPositiveRoc - cfg.HysteresisRoc) THEN cfg.IsPosRocActive = 0
    END IF

    ' Evaluate Negative ROC Alarm with Hysteresis
    IF cfg.IsNegRocActive = 0 THEN
        IF cfg.CurrentRoc <= -cfg.MaxNegativeRoc THEN cfg.IsNegRocActive = 1
    ELSE
        IF cfg.CurrentRoc >= (-cfg.MaxNegativeRoc + cfg.HysteresisRoc) THEN cfg.IsNegRocActive = 0
    END IF
END SUB
