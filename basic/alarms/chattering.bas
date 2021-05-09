' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Anti-Chattering Delay Timers & Alarm Flapping Suppression
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/alarms/chattering.bas
' ==============================================================================
'
' This module implements ANSI/ISA-18.2 compliant anti-chattering logic:
'   1. On-Delay Timers: Filters transient spikes; condition must persist for Ton
'   2. Off-Delay Timers: Prevents rapid re-triggering; must remain clear for Toff
'   3. Alarm Flapping Detection: Detects > 3 transitions per minute
' ==============================================================================

' ChatteringSuppressionState: Timer and transition counter memory
TYPE ChatteringSuppressionState
    OnDelayMs       AS DOUBLE   ' Required continuous duration before trip (e.g. 2000 ms)
    OffDelayMs      AS DOUBLE   ' Required continuous clear duration before reset (e.g. 5000 ms)

    RawConditionStartTimeMs AS DOUBLE  ' Time when condition first appeared
    RawClearStartTimeMs     AS DOUBLE  ' Time when condition first cleared

    TransitionCount AS INTEGER  ' Number of state changes in rolling evaluation window
    WindowStartTimeMs AS DOUBLE ' Start of rolling 60-second window
    IsChattering    AS INTEGER  ' 1 if flagged as chattering / flapping
    QualifiedAlarmState AS INTEGER ' Output filtered alarm condition (0 or 1)
END TYPE

' InitializeChatteringSuppression: Configures anti-chattering timers
SUB InitializeChatteringSuppression(state AS ChatteringSuppressionState, onMs AS DOUBLE, offMs AS DOUBLE)
    state.OnDelayMs = onMs > 0.0 ? onMs : 1000.0
    state.OffDelayMs = offMs > 0.0 ? offMs : 2000.0
    state.RawConditionStartTimeMs = 0.0
    state.RawClearStartTimeMs = 0.0
    state.TransitionCount = 0
    state.WindowStartTimeMs = 0.0
    state.IsChattering = 0
    state.QualifiedAlarmState = 0
END SUB

' EvaluateChatteringTimers: Evaluates raw condition with on-delay and off-delay filters
FUNCTION EvaluateChatteringTimers(state AS ChatteringSuppressionState, rawTripCondition AS INTEGER, currentClockMs AS DOUBLE) AS INTEGER
    ' 1. Rolling 60-second Flapping Assessment
    IF state.WindowStartTimeMs <= 0.0 THEN
        state.WindowStartTimeMs = currentClockMs
    ELSEIF (currentClockMs - state.WindowStartTimeMs) >= 60000.0 THEN
        ' Window elapsed: Reset transition counter
        state.WindowStartTimeMs = currentClockMs
        IF state.TransitionCount > 3 THEN
            state.IsChattering = 1
        ELSE
            state.IsChattering = 0
        END IF
        state.TransitionCount = 0
    END IF

    ' 2. On-Delay and Off-Delay Timer Evaluation
    IF rawTripCondition = 1 THEN
        state.RawClearStartTimeMs = 0.0  ' Clear reset timer

        IF state.QualifiedAlarmState = 0 THEN
            ' Currently normal. Evaluate On-Delay
            IF state.RawConditionStartTimeMs <= 0.0 THEN
                state.RawConditionStartTimeMs = currentClockMs
            ELSEIF (currentClockMs - state.RawConditionStartTimeMs) >= state.OnDelayMs THEN
                ' Condition has persisted for Ton: Qualify trip!
                state.QualifiedAlarmState = 1
                state.TransitionCount = state.TransitionCount + 1
            END IF
        END IF
    ELSE
        ' Raw condition is inactive (normal)
        state.RawConditionStartTimeMs = 0.0  ' Clear trip timer

        IF state.QualifiedAlarmState = 1 THEN
            ' Currently in alarm. Evaluate Off-Delay
            IF state.RawClearStartTimeMs <= 0.0 THEN
                state.RawClearStartTimeMs = currentClockMs
            ELSEIF (currentClockMs - state.RawClearStartTimeMs) >= state.OffDelayMs THEN
                ' Normal condition has persisted for Toff: Qualify clear!
                state.QualifiedAlarmState = 0
                state.TransitionCount = state.TransitionCount + 1
            END IF
        END IF
    END IF

    RETURN state.QualifiedAlarmState
END FUNCTION
