' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Alarm Annunciator & Audible Horn State Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/alarms/annunciator.bas
' ==============================================================================
'
' This module implements ISA-18.1 annunciator visual and acoustic sequences:
'   - Fast Flash (2 Hz): Unacknowledged active alarm, horn sounding
'   - Steady Illumination: Acknowledged active alarm, horn silenced
'   - Slow Flash (0.5 Hz): Returned-to-normal unacknowledged alarm
'   - Dark / Off: Normal cleared state
' ==============================================================================

CONST ANNUN_FLASH_OFF        = 0
CONST ANNUN_FLASH_STEADY     = 1
CONST ANNUN_FLASH_FAST       = 2  ' 2 Hz flashing
CONST ANNUN_FLASH_SLOW       = 3  ' 0.5 Hz flashing

' PlantAlarmSummary: Aggregated operational metrics across plant alarms
TYPE PlantAlarmSummary
    TotalActiveCount    AS INTEGER  ' Number of currently tripped alarms
    TotalUnackCount     AS INTEGER  ' Alarms requiring operator acknowledgment
    HighestActiveSev    AS INTEGER  ' Most critical active severity (0-4)
    IsHornSounding      AS INTEGER  ' 1 if audible warning active
    IsEmergencyTripped  AS INTEGER  ' 1 if Emergency severity alarm active
END TYPE

' GetAnnunciatorFlashMode: Computes lamp flashing state from ISA-18.2 alarm state
FUNCTION GetAnnunciatorFlashMode(alarmState AS INTEGER) AS INTEGER
    IF alarmState = ALARM_STATE_NORMAL THEN
        RETURN ANNUN_FLASH_OFF
    ELSEIF alarmState = ALARM_STATE_UNACK THEN
        RETURN ANNUN_FLASH_FAST
    ELSEIF alarmState = ALARM_STATE_ACKED THEN
        RETURN ANNUN_FLASH_STEADY
    ELSEIF alarmState = ALARM_STATE_RTN_UNACK THEN
        RETURN ANNUN_FLASH_SLOW
    ELSEIF alarmState = ALARM_STATE_SHELVED THEN
        RETURN ANNUN_FLASH_OFF
    END IF
    RETURN ANNUN_FLASH_OFF
END FUNCTION

' UpdatePlantAlarmSummary: Recalculates plant-wide alarm summary metrics
SUB UpdatePlantAlarmSummary(summary AS PlantAlarmSummary, alarmStates(100) AS INTEGER, _
                            alarmSeverities(100) AS INTEGER, count AS INTEGER)
    summary.TotalActiveCount = 0
    summary.TotalUnackCount = 0
    summary.HighestActiveSev = 0
    summary.IsEmergencyTripped = 0

    DIM i AS INTEGER
    FOR i = 0 TO count - 1
        DIM st AS INTEGER : st = alarmStates(i)
        DIM sev AS INTEGER : sev = alarmSeverities(i)

        IF st = ALARM_STATE_UNACK OR st = ALARM_STATE_ACKED OR st = ALARM_STATE_RTN_UNACK THEN
            summary.TotalActiveCount = summary.TotalActiveCount + 1
            IF sev > summary.HighestActiveSev THEN
                summary.HighestActiveSev = sev
            END IF
            IF sev = ALARM_SEV_EMERGENCY THEN
                summary.IsEmergencyTripped = 1
            END IF
        END IF

        IF st = ALARM_STATE_UNACK OR st = ALARM_STATE_RTN_UNACK THEN
            summary.TotalUnackCount = summary.TotalUnackCount + 1
        END IF
    NEXT i

    ' Audible horn sounds if there are any unacknowledged alarms
    IF summary.TotalUnackCount > 0 THEN
        summary.IsHornSounding = 1
    ELSE
        summary.IsHornSounding = 0
    END IF
END SUB
