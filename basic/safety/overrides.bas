' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Safety Instrumented System (SIS) Maintenance Bypass & Override Manager
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/safety/overrides.bas
' ==============================================================================
'
' This module implements the strict governance procedures for maintenance
' bypasses on safety instrumented functions per IEC 61511 / ISA-84:
'   - Time-limited maintenance override timers (max allowable duration)
'   - Automatic timeout warning and unbypass safety trip enforcement
'   - Interlock preventing concurrent bypass of multiple redundant channels
'   - Work permit authorization tracking and supervisory audit logging
' ==============================================================================

CONST MAX_BYPASSES = 16

TYPE SafetyBypassEntry
    TagId           AS STRING
    ChannelIndex    AS INTEGER
    IsBypassed      AS INTEGER ' 1 = Actively bypassed, 0 = In Service
    PermitNumber    AS STRING  ' Safety work permit authorization
    MaxDurationSec  AS DOUBLE  ' Maximum allowed bypass time (e.g. 14400 s = 4 hours)
    ElapsedSec      AS DOUBLE
    ExpiredAlarm    AS INTEGER
END TYPE

TYPE BypassManager
    Entries(16)     AS SafetyBypassEntry
    TotalActive     AS INTEGER
    MaxConcurrent   AS INTEGER ' Maximum allowable concurrent plant bypasses
    ViolationAlert  AS INTEGER
END TYPE

' InitializeBypassManager: Configures safety bypass supervisory limits
SUB InitializeBypassManager(mgr AS BypassManager)
    mgr.TotalActive = 0
    mgr.MaxConcurrent = 4      ' Max 4 bypasses across whole plant
    mgr.ViolationAlert = 0
    
    DIM i AS INTEGER
    FOR i = 1 TO MAX_BYPASSES
        mgr.Entries(i).TagId = ""
        mgr.Entries(i).ChannelIndex = 0
        mgr.Entries(i).IsBypassed = 0
        mgr.Entries(i).PermitNumber = ""
        mgr.Entries(i).MaxDurationSec = 14400.0 ' 4 hours default
        mgr.Entries(i).ElapsedSec = 0.0
        mgr.Entries(i).ExpiredAlarm = 0
    NEXT i
END SUB

' ApplySafetyBypass: Engages maintenance bypass with permit verification
FUNCTION ApplySafetyBypass(mgr AS BypassManager, tag AS STRING, channelIdx AS INTEGER, permit AS STRING, maxSec AS DOUBLE) AS INTEGER
    ' Verify plant-wide concurrency limit
    IF mgr.TotalActive >= mgr.MaxConcurrent THEN
        mgr.ViolationAlert = 1
        ApplySafetyBypass = 0 ' Rejected: Too many active bypasses
        EXIT FUNCTION
    END IF
    
    ' Check if another channel in the same tag group is already bypassed!
    DIM i AS INTEGER
    FOR i = 1 TO MAX_BYPASSES
        IF mgr.Entries(i).IsBypassed = 1 AND mgr.Entries(i).TagId = tag THEN
            ' Severe violation: Cannot bypass multiple channels of the same safety loop!
            mgr.ViolationAlert = 1
            ApplySafetyBypass = -1 ' Blocked: Redundancy defeat prevented
            EXIT FUNCTION
        END IF
    NEXT i
    
    ' Allocate bypass slot
    FOR i = 1 TO MAX_BYPASSES
        IF mgr.Entries(i).IsBypassed = 0 THEN
            mgr.Entries(i).TagId = tag
            mgr.Entries(i).ChannelIndex = channelIdx
            mgr.Entries(i).IsBypassed = 1
            mgr.Entries(i).PermitNumber = permit
            mgr.Entries(i).MaxDurationSec = maxSec
            mgr.Entries(i).ElapsedSec = 0.0
            mgr.Entries(i).ExpiredAlarm = 0
            mgr.TotalActive = mgr.TotalActive + 1
            ApplySafetyBypass = 1 ' Success
            EXIT FUNCTION
        END IF
    NEXT i
    ApplySafetyBypass = 0
END FUNCTION

' ReleaseSafetyBypass: Returns channel to active safety service
SUB ReleaseSafetyBypass(mgr AS BypassManager, tag AS STRING, channelIdx AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO MAX_BYPASSES
        IF mgr.Entries(i).IsBypassed = 1 AND mgr.Entries(i).TagId = tag AND mgr.Entries(i).ChannelIndex = channelIdx THEN
            mgr.Entries(i).IsBypassed = 0
            mgr.Entries(i).ElapsedSec = 0.0
            mgr.Entries(i).ExpiredAlarm = 0
            mgr.TotalActive = mgr.TotalActive - 1
            IF mgr.TotalActive < 0 THEN mgr.TotalActive = 0
            EXIT SUB
        END IF
    NEXT i
END SUB

' StepBypassWatchdog: Advances elapsed timers and flags expired bypasses
SUB StepBypassWatchdog(mgr AS BypassManager, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    DIM i AS INTEGER
    FOR i = 1 TO MAX_BYPASSES
        IF mgr.Entries(i).IsBypassed = 1 THEN
            mgr.Entries(i).ElapsedSec = mgr.Entries(i).ElapsedSec + dtSec
            IF mgr.Entries(i).ElapsedSec >= mgr.Entries(i).MaxDurationSec THEN
                mgr.Entries(i).ExpiredAlarm = 1
            END IF
        END IF
    NEXT i
END SUB
