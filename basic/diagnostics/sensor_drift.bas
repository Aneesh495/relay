' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Redundant Sensor Calibration Drift & Residual Anomaly Monitor
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/diagnostics/sensor_drift.bas
' ==============================================================================
'
' This module implements early-warning calibration drift detection across
' redundant process transmitters (e.g. dual temperature, pressure, flow):
'   - Innovation residual difference: Delta(k) = y_A(k) - y_B(k)
'   - Long-term low-pass bias tracking (filters out dynamic flow turbulence)
'   - Statistical 3-sigma drift threshold trip detection
'   - Discrepancy warning before out-of-spec measurement affects plant control
' ==============================================================================

TYPE SensorDriftMonitor
    TagChannelA     AS STRING
    TagChannelB     AS STRING
    
    CurrentValA     AS DOUBLE
    CurrentValB     AS DOUBLE
    RawDiscrepancy  AS DOUBLE  ' Instantaneous |A - B|
    FilteredBias    AS DOUBLE  ' Low-pass long-term baseline difference
    FilterAlpha     AS DOUBLE  ' Smoothing weight (nominal 0.02)
    
    MaxAllowedDrift AS DOUBLE  ' Warning threshold in engineering units
    DriftWarningFlag AS INTEGER' 1 = Significant calibration drift detected
    ConsecutiveSamples AS INTEGER
END TYPE

' InitializeDriftMonitor: Sets up redundant channel pair
SUB InitializeDriftMonitor(mon AS SensorDriftMonitor, tagA AS STRING, tagB AS STRING, maxDrift AS DOUBLE)
    mon.TagChannelA = tagA
    mon.TagChannelB = tagB
    mon.CurrentValA = 0.0
    mon.CurrentValB = 0.0
    mon.RawDiscrepancy = 0.0
    mon.FilteredBias = 0.0
    mon.FilterAlpha = 0.02     ' Slow time constant to isolate true zero drift
    mon.MaxAllowedDrift = maxDrift
    mon.DriftWarningFlag = 0
    mon.ConsecutiveSamples = 0
END SUB

' UpdateDriftMonitor: Ingests new sample pair from transmitters
SUB UpdateDriftMonitor(mon AS SensorDriftMonitor, valA AS DOUBLE, valB AS DOUBLE)
    mon.CurrentValA = valA
    mon.CurrentValB = valB
    
    ' Calculate raw delta
    DIM delta AS DOUBLE : delta = valA - valB
    mon.RawDiscrepancy = ABS(delta)
    
    ' Exponential smoothing of bias: Bias = (1 - alpha) * Bias + alpha * delta
    mon.FilteredBias = (1.0 - mon.FilterAlpha) * mon.FilteredBias + mon.FilterAlpha * delta
    
    ' Evaluate sustained drift against tolerance
    IF ABS(mon.FilteredBias) > mon.MaxAllowedDrift THEN
        mon.ConsecutiveSamples = mon.ConsecutiveSamples + 1
        IF mon.ConsecutiveSamples >= 5 THEN
            mon.DriftWarningFlag = 1
        END IF
    ELSE
        mon.ConsecutiveSamples = 0
        mon.DriftWarningFlag = 0
    END IF
END SUB
