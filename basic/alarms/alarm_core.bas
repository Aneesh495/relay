' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' ISA-18.2 / EEMUA 191 Alarm Management State Machine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/alarms/alarm_core.bas
' ==============================================================================
'
' This module implements the international alarm lifecycle state machine
' defined in ANSI/ISA-18.2 and EEMUA 191:
'   - Normal (cleared, silent)
'   - Unacknowledged Active (limit breached, alarm flashing/sounding)
'   - Acknowledged Active (operator acknowledged, steady alarm state)
'   - Returned to Normal Unacknowledged (process back in band, awaiting final ack)
'   - Shelved (temporarily suppressed by authorized operator)
'   - Suppressed by Design (disabled by control logic state or equipment offline)
' ==============================================================================

' ProcessAlarmLifecycleStep: Evaluates raw condition and drives ISA-18.2 state transitions
SUB ProcessAlarmLifecycleStep(alm AS AlarmDefinition, isConditionActive AS INTEGER, _
                              isOperatorAck AS INTEGER, currentClockMs AS DOUBLE)
    ' 1. Check if Shelved
    IF alm.IsShelved = 1 THEN
        IF currentClockMs >= alm.ShelveTimeoutMs THEN
            ' Shelve period expired! Automatically un-shelve
            alm.IsShelved = 0
            alm.State = isConditionActive = 1 ? ALARM_STATE_UNACK : ALARM_STATE_NORMAL
        ELSE
            alm.State = ALARM_STATE_SHELVED
            EXIT SUB
        END IF
    END IF

    ' 2. State Machine Evaluation
    IF alm.State = ALARM_STATE_NORMAL THEN
        IF isConditionActive = 1 THEN
            ' Limit breached: Transition to Unacknowledged Alarm
            alm.State = ALARM_STATE_UNACK
            alm.TripTimestampMs = currentClockMs
        END IF

    ELSEIF alm.State = ALARM_STATE_UNACK THEN
        IF isOperatorAck = 1 THEN
            IF isConditionActive = 1 THEN
                ' Acknowledged while still active: Transition to Acknowledged
                alm.State = ALARM_STATE_ACKED
                alm.AckTimestampMs = currentClockMs
            ELSE
                ' Acknowledged after condition cleared: Return to Normal
                alm.State = ALARM_STATE_NORMAL
                alm.AckTimestampMs = currentClockMs
                alm.RtnTimestampMs = currentClockMs
            END IF
        ELSEIF isConditionActive = 0 THEN
            ' Condition cleared before operator acknowledged: Transition to RTN_Unack
            alm.State = ALARM_STATE_RTN_UNACK
            alm.RtnTimestampMs = currentClockMs
        END IF

    ELSEIF alm.State = ALARM_STATE_ACKED THEN
        IF isConditionActive = 0 THEN
            ' Process returned to normal: Transition to Normal
            alm.State = ALARM_STATE_NORMAL
            alm.RtnTimestampMs = currentClockMs
        END IF

    ELSEIF alm.State = ALARM_STATE_RTN_UNACK THEN
        IF isOperatorAck = 1 THEN
            ' Operator acknowledged cleared state: Transition to Normal
            alm.State = ALARM_STATE_NORMAL
            alm.AckTimestampMs = currentClockMs
        ELSEIF isConditionActive = 1 THEN
            ' Re-tripped before being acknowledged: Return to Unacknowledged
            alm.State = ALARM_STATE_UNACK
            alm.TripTimestampMs = currentClockMs
        END IF
    END IF
END SUB

' ShelveAlarm: Temporarily suppresses an alarm for a specified duration in milliseconds
SUB ShelveAlarm(alm AS AlarmDefinition, durationMs AS DOUBLE, currentClockMs AS DOUBLE)
    alm.IsShelved = 1
    alm.ShelveTimeoutMs = currentClockMs + durationMs
    alm.State = ALARM_STATE_SHELVED
END SUB

' UnShelveAlarm: Manually removes shelving and restores active monitoring
SUB UnShelveAlarm(alm AS AlarmDefinition, isConditionActive AS INTEGER)
    alm.IsShelved = 0
    alm.ShelveTimeoutMs = 0.0
    IF isConditionActive = 1 THEN
        alm.State = ALARM_STATE_UNACK
    ELSE
        alm.State = ALARM_STATE_NORMAL
    END IF
END SUB
