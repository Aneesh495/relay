' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Operator Alarm Shelving & Designed State Suppression
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/alarms/shelving.bas
' ==============================================================================
'
' This module implements alarm shelving according to ANSI/ISA-18.2. Shelving
' allows authorized console operators to temporarily suppress nuisance alarms
' with an enforceable expiration timeout.
' ==============================================================================

CONST SHELVE_REASON_MAINTENANCE   = 1  ' Equipment actively undergoing servicing
CONST SHELVE_REASON_KNOWN_DEFECT  = 2  ' Instrument awaiting parts / calibration
CONST SHELVE_REASON_STARTUP       = 3  ' Expected transient during plant startup
CONST SHELVE_REASON_PROCESS_TEST  = 4  ' Engineering test or chemical trial

' ShelveRecord: Audit record for an actively shelved alarm
TYPE ShelveRecord
    AlarmId         AS INTEGER  ' Identifier of suppressed alarm
    ReasonCode      AS INTEGER  ' Maintenance, Defect, Startup, Testing
    ShelvedTimeMs   AS DOUBLE   ' Timestamp when shelved
    ExpirationTimeMs AS DOUBLE  ' Clock time when shelving must automatically expire
    OperatorId      AS STRING   ' Identity of authorized operator
    IsActive        AS INTEGER  ' 1 if actively shelved, 0 if expired
END TYPE

' ApplyOperatorShelving: Registers a new shelving record with maximum timeout enforcement
FUNCTION ApplyOperatorShelving(rec AS ShelveRecord, almId AS INTEGER, reason AS INTEGER, _
                               durationMinutes AS DOUBLE, opId AS STRING, currentClockMs AS DOUBLE) AS INTEGER
    ' Enforce maximum 24-hour shelving limit per ISA-18.2
    IF durationMinutes > 1440.0 THEN durationMinutes = 1440.0
    IF durationMinutes <= 0.0 THEN RETURN 0

    rec.AlarmId = almId
    rec.ReasonCode = reason
    rec.ShelvedTimeMs = currentClockMs
    rec.ExpirationTimeMs = currentClockMs + durationMinutes * 60000.0
    rec.OperatorId = opId
    rec.IsActive = 1
    RETURN 1
END FUNCTION

' CheckShelveExpiration: Verifies whether shelving window has expired
FUNCTION CheckShelveExpiration(rec AS ShelveRecord, currentClockMs AS DOUBLE) AS INTEGER
    IF rec.IsActive = 0 THEN RETURN 1
    IF currentClockMs >= rec.ExpirationTimeMs THEN
        rec.IsActive = 0
        RETURN 1  ' Expired! Must re-enable alarm monitoring
    END IF
    RETURN 0  ' Still actively shelved
END FUNCTION
