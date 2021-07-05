' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Real-Time Alarm Summary Banner & Annunciator View
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/hmi/alarm_banner.bas
' ==============================================================================
'
' This module implements the standard ISA-18.2 operator alarm banner
' and active alarm summary list for industrial control room display:
'   - Multi-tier priority color sorting: Critical, High, Medium, Low
'   - Unacknowledged flashing and audible horn alert state
'   - Chronological first-in first-out alarm stream
'   - Operator one-touch acknowledge and silence commands
' ==============================================================================

TYPE AlarmBannerEntry
    AlarmId         AS INTEGER
    TagIdentifier   AS STRING
    Description     AS STRING
    TripTimeStr     AS STRING
    PriorityLevel   AS INTEGER ' 1 = Critical, 2 = High, 3 = Medium, 4 = Low
    AlarmTypeStr    AS STRING  ' "HI-HI", "HIGH", "LO-LO", "LOW", "ROC"
    CurrentValue    AS DOUBLE
    TripLimit       AS DOUBLE
    Units           AS STRING
    IsAcknowledged  AS INTEGER ' 1 = Acked, 0 = Unacknowledged (Flashing)
END TYPE

TYPE AlarmBannerManager
    ActiveAlarms(20) AS AlarmBannerEntry
    ActiveCount     AS INTEGER
    UnackCount      AS INTEGER
    HornActive      AS INTEGER ' 1 = Audible annunciator sounding
    MaxDisplayRows  AS INTEGER
END TYPE

' InitializeAlarmBanner: Sets up operator alarm banner state
SUB InitializeAlarmBanner(mgr AS AlarmBannerManager, maxRows AS INTEGER)
    mgr.ActiveCount = 0
    mgr.UnackCount = 0
    mgr.HornActive = 0
    IF maxRows > 2 THEN
        mgr.MaxDisplayRows = maxRows
    ELSE
        mgr.MaxDisplayRows = 5
    END IF
END SUB

' IngestAlarmEvent: Adds or updates an active alarm in the banner
SUB IngestAlarmEvent(mgr AS AlarmBannerManager, almId AS INTEGER, tagId AS STRING, desc AS STRING, timeStr AS STRING, prio AS INTEGER, almType AS STRING, pv AS DOUBLE, lim AS DOUBLE, eu AS STRING)
    ' Check if alarm already present
    DIM i AS INTEGER
    FOR i = 1 TO mgr.ActiveCount
        IF mgr.ActiveAlarms(i).AlarmId = almId THEN
            mgr.ActiveAlarms(i).CurrentValue = pv
            EXIT SUB
        END IF
    NEXT i
    
    ' New alarm: shift entries down if full
    IF mgr.ActiveCount < 20 THEN
        mgr.ActiveCount = mgr.ActiveCount + 1
    END IF
    
    FOR i = mgr.ActiveCount TO 2 STEP -1
        mgr.ActiveAlarms(i) = mgr.ActiveAlarms(i - 1)
    NEXT i
    
    mgr.ActiveAlarms(1).AlarmId = almId
    mgr.ActiveAlarms(1).TagIdentifier = tagId
    mgr.ActiveAlarms(1).Description = desc
    mgr.ActiveAlarms(1).TripTimeStr = timeStr
    mgr.ActiveAlarms(1).PriorityLevel = prio
    mgr.ActiveAlarms(1).AlarmTypeStr = almType
    mgr.ActiveAlarms(1).CurrentValue = pv
    mgr.ActiveAlarms(1).TripLimit = lim
    mgr.ActiveAlarms(1).Units = eu
    mgr.ActiveAlarms(1).IsAcknowledged = 0
    
    mgr.UnackCount = mgr.UnackCount + 1
    mgr.HornActive = 1
END SUB

' AcknowledgeAllAlarms: Operator clears flashing unacknowledged status
SUB AcknowledgeAllAlarms(mgr AS AlarmBannerManager)
    DIM i AS INTEGER
    FOR i = 1 TO mgr.ActiveCount
        mgr.ActiveAlarms(i).IsAcknowledged = 1
    NEXT i
    mgr.UnackCount = 0
    mgr.HornActive = 0
END SUB

' RenderAlarmBanner: Prints high-visibility ANSI alarm table to terminal
SUB RenderAlarmBanner(mgr AS AlarmBannerManager)
    PRINT "================================================================================"
    PRINT " ACTIVE ALARM BANNER (ISA-18.2) | ACTIVE: "; mgr.ActiveCount; " | UNACK: "; mgr.UnackCount;
    IF mgr.HornActive = 1 THEN
        PRINT " | [! HORN SOUNDING !]"
    ELSE
        PRINT " | [ HORN SILENT ]"
    END IF
    PRINT "--------------------------------------------------------------------------------"
    PRINT " TIME     | PRIO | TAG        | TYPE  | VALUE   | LIMIT   | EU   | DESCRIPTION"
    PRINT "----------+------+------------+-------+---------+---------+------+--------------"
    
    DIM showCount AS INTEGER
    IF mgr.ActiveCount < mgr.MaxDisplayRows THEN
        showCount = mgr.ActiveCount
    ELSE
        showCount = mgr.MaxDisplayRows
    END IF
    
    IF showCount = 0 THEN
        PRINT " [ ALL SYSTEMS NORMAL - NO ACTIVE PROCESS ALARMS ]"
    ELSE
        DIM i AS INTEGER
        FOR i = 1 TO showCount
            DIM prioStr AS STRING
            IF mgr.ActiveAlarms(i).PriorityLevel = 1 THEN
                prioStr = "CRIT"
            ELSEIF mgr.ActiveAlarms(i).PriorityLevel = 2 THEN
                prioStr = "HIGH"
            ELSEIF mgr.ActiveAlarms(i).PriorityLevel = 3 THEN
                prioStr = "MED "
            ELSE
                prioStr = "LOW "
            END IF
            
            DIM ackFlag AS STRING
            IF mgr.ActiveAlarms(i).IsAcknowledged = 0 THEN
                ackFlag = "*" ' Flashing unacknowledged
            ELSE
                ackFlag = " "
            END IF
            
            PRINT ackFlag; PadRight(mgr.ActiveAlarms(i).TripTimeStr, 8); " | ";
            PRINT prioStr; " | ";
            PRINT PadRight(mgr.ActiveAlarms(i).TagIdentifier, 10); " | ";
            PRINT PadRight(mgr.ActiveAlarms(i).AlarmTypeStr, 5); " | ";
            PRINT PadLeft(FormatDouble(mgr.ActiveAlarms(i).CurrentValue, 2), 7); " | ";
            PRINT PadLeft(FormatDouble(mgr.ActiveAlarms(i).TripLimit, 2), 7); " | ";
            PRINT PadRight(mgr.ActiveAlarms(i).Units, 4); " | ";
            PRINT mgr.ActiveAlarms(i).Description
        NEXT i
    END IF
    PRINT "================================================================================"
END SUB
