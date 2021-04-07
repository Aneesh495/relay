' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Deadband Filtering & Signal Noise Suppression Library
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/tags/deadband.bas
' ==============================================================================
'
' This module implements industrial deadband algorithms that filter raw sensor
' jitter, prevent telemetry flooding, and stabilize downstream control loops.
' ==============================================================================

' ------------------------------------------------------------------------------
' SECTION 1: ABSOLUTE AND PERCENT-OF-SPAN DEADBANDS
' ------------------------------------------------------------------------------

' CheckAbsoluteDeadband: Returns 1 if change exceeds absolute deadband delta
FUNCTION CheckAbsoluteDeadband(currentVal AS DOUBLE, lastVal AS DOUBLE, deadbandAbs AS DOUBLE) AS INTEGER
    DIM diff AS DOUBLE
    diff = ABS(currentVal - lastVal)
    IF diff >= deadbandAbs THEN
        RETURN 1
    END IF
    RETURN 0
END FUNCTION

' CheckPercentDeadband: Returns 1 if change exceeds percentage of tag span
FUNCTION CheckPercentDeadband(currentVal AS DOUBLE, lastVal AS DOUBLE, spanEu AS DOUBLE, deadbandPct AS DOUBLE) AS INTEGER
    IF spanEu <= 0.0 THEN RETURN 1
    DIM diff AS DOUBLE : diff = ABS(currentVal - lastVal)
    DIM threshold AS DOUBLE : threshold = spanEu * (deadbandPct * 0.01)
    IF diff >= threshold THEN
        RETURN 1
    END IF
    RETURN 0
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 2: ASYMMETRIC DIRECTIONAL DEADBANDS
' ------------------------------------------------------------------------------

' CheckAsymmetricDeadband: Evaluates change with distinct positive vs negative thresholds
' Useful for tank level filling vs draining or furnace heating vs cooling
FUNCTION CheckAsymmetricDeadband(currentVal AS DOUBLE, lastVal AS DOUBLE, posThreshold AS DOUBLE, negThreshold AS DOUBLE) AS INTEGER
    DIM delta AS DOUBLE
    delta = currentVal - lastVal
    IF delta > 0.0 AND delta >= posThreshold THEN
        RETURN 1
    END IF
    IF delta < 0.0 AND ABS(delta) >= negThreshold THEN
        RETURN 1
    END IF
    RETURN 0
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 3: TIME-DELAYED DEADBAND FILTER
' ------------------------------------------------------------------------------

' TimeDelayedDeadbandState: State memory for time-qualified deadband filter
TYPE TimeDelayedDeadbandState
    CandidateValue    AS DOUBLE  ' Potential new value outside deadband
    CandidateSinceMs  AS DOUBLE  ' Time when candidate first deviated
    HoldRequiredMs    AS DOUBLE  ' Duration candidate must remain stable
    IsPending         AS INTEGER ' 1 if timing active, 0 otherwise
END TYPE

' ProcessTimeDelayedDeadband: Filters high-frequency pulses; requires candidate
' value to persist outside deadband for holdMs before committing change.
FUNCTION ProcessTimeDelayedDeadband(state AS TimeDelayedDeadbandState, currentVal AS DOUBLE, _
                                    lastCommittedVal AS DOUBLE, deadbandAbs AS DOUBLE, _
                                    currentClockMs AS DOUBLE, holdMs AS DOUBLE, _
                                    emittedVal AS DOUBLE) AS INTEGER
    DIM diff AS DOUBLE
    diff = ABS(currentVal - lastCommittedVal)

    IF diff < deadbandAbs THEN
        ' Within deadband, reset pending timer
        state.IsPending = 0
        emittedVal = lastCommittedVal
        RETURN 0
    END IF

    ' Outside deadband
    IF state.IsPending = 0 THEN
        ' Start candidate timing window
        state.IsPending = 1
        state.CandidateValue = currentVal
        state.CandidateSinceMs = currentClockMs
        state.HoldRequiredMs = holdMs
        emittedVal = lastCommittedVal
        RETURN 0
    END IF

    ' Check if candidate has persisted for required hold time
    DIM elapsedMs AS DOUBLE
    elapsedMs = currentClockMs - state.CandidateSinceMs
    IF elapsedMs >= state.HoldRequiredMs THEN
        ' Candidate qualified! Commit new value
        state.IsPending = 0
        emittedVal = currentVal
        RETURN 1
    END IF

    emittedVal = lastCommittedVal
    RETURN 0
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 4: OUTLIER AND SPIKE REJECTION FILTER
' ------------------------------------------------------------------------------

' FilterSpikeOutlier: Rejects single-cycle wild readings exceeding max allowable rate of change
FUNCTION FilterSpikeOutlier(currentVal AS DOUBLE, prevVal AS DOUBLE, maxRatePerSec AS DOUBLE, dtSec AS DOUBLE) AS DOUBLE
    IF dtSec <= 0.0 THEN RETURN prevVal
    DIM maxAllowedDelta AS DOUBLE
    maxAllowedDelta = maxRatePerSec * dtSec
    DIM actualDelta AS DOUBLE
    actualDelta = currentVal - prevVal

    IF ABS(actualDelta) > maxAllowedDelta THEN
        ' Spike detected! Clamp change to max permissible rate
        IF actualDelta > 0.0 THEN
            RETURN prevVal + maxAllowedDelta
        ELSE
            RETURN prevVal - maxAllowedDelta
        END IF
    END IF

    RETURN currentVal
END FUNCTION
