' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Tag Quality Assessment & Fail-Safe Propagation Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/tags/quality.bas
' ==============================================================================
'
' This module implements the OPC DA industrial quality classification standard.
' It validates physical sensor integrity (4-20mA NAMUR NE 43 wire-break detection),
' detects flatline frozen sensors, and propagates degraded quality flags across
' mathematical calculation graphs and control interlocks.
' ==============================================================================

' NAMUR NE 43 Thresholds for 4-20mA Current Loops
CONST NAMUR_FAULT_LOW_MA   = 3.6   ' Sensor wire break or transmitter fault
CONST NAMUR_UNDERRANGE_MA  = 3.8   ' Low measuring limit exceeded
CONST NAMUR_OVERRANGE_MA   = 20.5  ' High measuring limit exceeded
CONST NAMUR_FAULT_HIGH_MA  = 21.0  ' Sensor short circuit or hardware fault

' ------------------------------------------------------------------------------
' SECTION 1: SIGNAL INTEGRITY EVALUATION
' ------------------------------------------------------------------------------

' EvaluateNamurCurrentLoop: Evaluates 4-20mA loop current according to NAMUR NE 43
FUNCTION EvaluateNamurCurrentLoop(loopCurrentMa AS DOUBLE) AS INTEGER
    IF loopCurrentMa < NAMUR_FAULT_LOW_MA THEN
        ' Open circuit, wire break, or transmitter loss of power
        RETURN QUALITY_BAD_SENSOR_FAIL
    END IF

    IF loopCurrentMa > NAMUR_FAULT_HIGH_MA THEN
        ' Short circuit or catastrophic internal electronics failure
        RETURN QUALITY_BAD_SENSOR_FAIL
    END IF

    IF loopCurrentMa < NAMUR_UNDERRANGE_MA OR loopCurrentMa > NAMUR_OVERRANGE_MA THEN
        ' Out of measurement specification but physically connected
        RETURN QUALITY_UNCERTAIN
    END IF

    RETURN QUALITY_GOOD
END FUNCTION

' EvaluateTagQuality: Comprehensive quality evaluation for general process tags
FUNCTION EvaluateTagQuality(rawVal AS DOUBLE, rawMin AS DOUBLE, rawMax AS DOUBLE, _
                            commTimeout AS INTEGER, isForcedManual AS INTEGER) AS INTEGER
    IF isForcedManual = 1 THEN
        RETURN QUALITY_MANUAL_OVERRIDE
    END IF

    IF commTimeout = 1 THEN
        RETURN QUALITY_BAD_COMM_FAIL
    END IF

    ' Raw count range validation with 5% safety margin
    DIM spanRaw AS DOUBLE : spanRaw = rawMax - rawMin
    DIM lowThreshold AS DOUBLE : lowThreshold = rawMin - spanRaw * 0.05
    DIM highThreshold AS DOUBLE : highThreshold = rawMax + spanRaw * 0.05

    IF rawVal < lowThreshold OR rawVal > highThreshold THEN
        RETURN QUALITY_BAD_SENSOR_FAIL
    END IF

    RETURN QUALITY_GOOD
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 2: FROZEN SENSOR AND FLATLINE DETECTION
' ------------------------------------------------------------------------------

' SensorFlatlineDetector: State memory tracking sensor stagnation
TYPE SensorFlatlineDetector
    LastValue        AS DOUBLE  ' Monitored process value
    LastChangedTimeMs AS DOUBLE  ' Time when value last varied beyond deadband
    MaxStagnantMs    AS DOUBLE  ' Maximum allowed unchanging period before fault
    IsFlatlined      AS INTEGER ' 1 if sensor detected as frozen, 0 otherwise
END TYPE

' CheckSensorFlatline: Flags quality degradation if a continuous process sensor
' exhibits zero variation for longer than maxStagnantMs.
FUNCTION CheckSensorFlatline(detector AS SensorFlatlineDetector, currentVal AS DOUBLE, _
                             currentClockMs AS DOUBLE, minVarianceEu AS DOUBLE) AS INTEGER
    DIM delta AS DOUBLE
    delta = ABS(currentVal - detector.LastValue)

    IF delta > minVarianceEu THEN
        ' Sensor actively varying, reset flatline timer
        detector.LastValue = currentVal
        detector.LastChangedTimeMs = currentClockMs
        detector.IsFlatlined = 0
        RETURN 0
    END IF

    DIM stagnantDuration AS DOUBLE
    stagnantDuration = currentClockMs - detector.LastChangedTimeMs
    IF stagnantDuration >= detector.MaxStagnantMs THEN
        ' Sensor flatlined! Transmitter likely frozen or mechanically stuck
        detector.IsFlatlined = 1
        RETURN 1
    END IF

    RETURN 0
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 3: QUALITY PROPAGATION ACROSS DATAFLOW GRAPHS
' ------------------------------------------------------------------------------

' PropagateQuality2: Computes resulting quality for an operation with 2 inputs.
' Rules:
'   1. If either input is BAD, output is BAD.
'   2. If either input is UNCERTAIN (and neither is BAD), output is UNCERTAIN.
'   3. If either input is MANUAL, output is MANUAL.
'   4. Otherwise, output is GOOD.
FUNCTION PropagateQuality2(q1 AS INTEGER, q2 AS INTEGER) AS INTEGER
    IF q1 = QUALITY_BAD_SENSOR_FAIL OR q2 = QUALITY_BAD_SENSOR_FAIL THEN
        RETURN QUALITY_BAD_SENSOR_FAIL
    END IF
    IF q1 = QUALITY_BAD_COMM_FAIL OR q2 = QUALITY_BAD_COMM_FAIL THEN
        RETURN QUALITY_BAD_COMM_FAIL
    END IF
    IF q1 = QUALITY_BAD_NONSPECIFIC OR q2 = QUALITY_BAD_NONSPECIFIC THEN
        RETURN QUALITY_BAD_NONSPECIFIC
    END IF

    IF q1 = QUALITY_UNCERTAIN OR q2 = QUALITY_UNCERTAIN THEN
        RETURN QUALITY_UNCERTAIN
    END IF

    IF q1 = QUALITY_MANUAL_OVERRIDE OR q2 = QUALITY_MANUAL_OVERRIDE THEN
        RETURN QUALITY_MANUAL_OVERRIDE
    END IF

    RETURN QUALITY_GOOD
END FUNCTION
