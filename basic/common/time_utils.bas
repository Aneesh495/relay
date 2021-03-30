' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' High-Resolution Process Timing & Loop Jitter Estimation
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/common/time_utils.bas
' ==============================================================================
'
' This module implements high-resolution time formatting, execution jitter
' diagnostics, and periodic cycle scheduler tracking for hard real-time control loops.
' ==============================================================================

' ------------------------------------------------------------------------------
' SECTION 1: DURATION AND TIMESTAMP FORMATTING
' ------------------------------------------------------------------------------

' FormatDurationSeconds: Formats a duration in seconds into HH:MM:SS format
FUNCTION FormatDurationSeconds(totalSec AS DOUBLE) AS STRING
    DIM intSec AS INTEGER : intSec = INT(totalSec)
    DIM hours AS INTEGER : hours = intSec \ 3600
    DIM remSec AS INTEGER : remSec = intSec MOD 3600
    DIM mins AS INTEGER : mins = remSec \ 60
    DIM secs AS INTEGER : secs = remSec MOD 60

    DIM sH AS STRING : sH = STR$(hours)
    DIM sM AS STRING : sM = STR$(mins)
    DIM sS AS STRING : sS = STR$(secs)

    IF LEN(sH) < 2 THEN sH = "0" + sH
    IF LEN(sM) < 2 THEN sM = "0" + sM
    IF LEN(sS) < 2 THEN sS = "0" + sS

    RETURN sH + ":" + sM + ":" + sS
END FUNCTION

' FormatElapsedMs: Formats millisecond duration into fractional seconds (e.g. "124.5 ms")
FUNCTION FormatElapsedMs(ms AS DOUBLE) AS STRING
    IF ms < 1000.0 THEN
        RETURN STR$(INT(ms)) + " ms"
    ELSE
        DIM sec AS DOUBLE : sec = ms / 1000.0
        DIM iSec AS INTEGER : iSec = INT(sec)
        DIM frac AS INTEGER : frac = INT((sec - iSec) * 10.0)
        RETURN STR$(iSec) + "." + STR$(frac) + " s"
    END IF
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 2: HARD REAL-TIME LOOP JITTER ANALYSIS
' ------------------------------------------------------------------------------

' LoopJitterTracker: Tracks real-time loop execution period deviations
TYPE LoopJitterTracker
    TargetPeriodMs  AS DOUBLE  ' Nominal configured period (e.g. 50.0 ms)
    LastTimestampMs AS DOUBLE  ' Clock value at preceding execution cycle
    SampleCount     AS INTEGER ' Total execution cycles recorded
    SumDeviationMs  AS DOUBLE  ' Accumulated sum of absolute timing errors
    MaxJitterMs     AS DOUBLE  ' Worst-case observed jitter deviation
    OverrunCount    AS INTEGER ' Total cycles exceeding 150% of target period
END TYPE

' InitializeJitterTracker: Prepares jitter diagnostic monitor
SUB InitializeJitterTracker(tracker AS LoopJitterTracker, targetMs AS DOUBLE)
    tracker.TargetPeriodMs = targetMs
    tracker.LastTimestampMs = 0.0
    tracker.SampleCount = 0
    tracker.SumDeviationMs = 0.0
    tracker.MaxJitterMs = 0.0
    tracker.OverrunCount = 0
END SUB

' RecordLoopCycle: Evaluates elapsed cycle time and updates jitter statistics
SUB RecordLoopCycle(tracker AS LoopJitterTracker, currentMs AS DOUBLE, actualDeltaMs AS DOUBLE)
    IF tracker.LastTimestampMs <= 0.0 THEN
        tracker.LastTimestampMs = currentMs
        actualDeltaMs = tracker.TargetPeriodMs
        EXIT SUB
    END IF

    actualDeltaMs = currentMs - tracker.LastTimestampMs
    tracker.LastTimestampMs = currentMs
    tracker.SampleCount = tracker.SampleCount + 1

    DIM deviation AS DOUBLE
    deviation = ABS(actualDeltaMs - tracker.TargetPeriodMs)
    tracker.SumDeviationMs = tracker.SumDeviationMs + deviation

    IF deviation > tracker.MaxJitterMs THEN
        tracker.MaxJitterMs = deviation
    END IF

    IF actualDeltaMs > (tracker.TargetPeriodMs * 1.5) THEN
        tracker.OverrunCount = tracker.OverrunCount + 1
    END IF
END SUB

' GetAverageJitterMs: Computes the mean cycle jitter over all recorded cycles
FUNCTION GetAverageJitterMs(tracker AS LoopJitterTracker) AS DOUBLE
    IF tracker.SampleCount <= 0 THEN RETURN 0.0
    RETURN tracker.SumDeviationMs / tracker.SampleCount
END FUNCTION
