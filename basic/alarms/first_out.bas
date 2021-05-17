' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' First-Out Annunciator & Trip Cascade Attribution Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/alarms/first_out.bas
' ==============================================================================
'
' When major rotating equipment or chemical units trip (e.g., centrifugal compressor
' or steam turbine), dozens of secondary alarms cascade simultaneously. The
' First-Out annunciator isolates the exact primary root cause trip that initiated
' the shutdown, latching it and suppressing downstream cascade confusion.
' ==============================================================================

CONST MAX_FIRST_OUT_INPUTS = 16

' FirstOutGroupRecord: Latching state for a group of interlocked trip inputs
TYPE FirstOutGroupRecord
    GroupId         AS INTEGER  ' Unique identifier for trip group
    IsLatched       AS INTEGER  ' 1 if a root-cause trip has already occurred
    RootCauseIndex  AS INTEGER  ' Index of the trip that triggered first (-1 if none)
    RootTimestampMs AS DOUBLE   ' Exact sub-millisecond timestamp of the root trip
    InputIds(16)    AS INTEGER  ' Array of monitored trip alarm identifiers
    InputCount      AS INTEGER  ' Number of inputs monitored in group
END TYPE

' InitializeFirstOutGroup: Resets group latching state
SUB InitializeFirstOutGroup(grp AS FirstOutGroupRecord, gId AS INTEGER)
    grp.GroupId = gId
    grp.IsLatched = 0
    grp.RootCauseIndex = -1
    grp.RootTimestampMs = 0.0
    grp.InputCount = 0
    DIM i AS INTEGER
    FOR i = 0 TO MAX_FIRST_OUT_INPUTS - 1
        grp.InputIds(i) = -1
    NEXT i
END SUB

' AddFirstOutInput: Associates a trip alarm point with this group
FUNCTION AddFirstOutInput(grp AS FirstOutGroupRecord, alarmId AS INTEGER) AS INTEGER
    IF grp.InputCount >= MAX_FIRST_OUT_INPUTS THEN RETURN -1
    DIM idx AS INTEGER : idx = grp.InputCount
    grp.InputIds(idx) = alarmId
    grp.InputCount = grp.InputCount + 1
    RETURN idx
END FUNCTION

' ProcessFirstOutEvents: Evaluates new trip conditions against group latch
FUNCTION ProcessFirstOutEvents(grp AS FirstOutGroupRecord, activeTrips(16) AS INTEGER, _
                               eventTimestamps(16) AS DOUBLE) AS INTEGER
    ' If already latched, the root cause is established and locked!
    IF grp.IsLatched = 1 THEN
        RETURN grp.RootCauseIndex
    END IF

    ' Scan for earliest trip condition
    DIM earliestTime AS DOUBLE : earliestTime = 1.0E30
    DIM earliestIdx AS INTEGER : earliestIdx = -1
    DIM i AS INTEGER

    FOR i = 0 TO grp.InputCount - 1
        IF activeTrips(i) = 1 THEN
            IF eventTimestamps(i) < earliestTime THEN
                earliestTime = eventTimestamps(i)
                earliestIdx = i
            END IF
        END IF
    NEXT i

    IF earliestIdx >= 0 THEN
        ' Latch the first-out root cause trip!
        grp.IsLatched = 1
        grp.RootCauseIndex = earliestIdx
        grp.RootTimestampMs = earliestTime
        RETURN earliestIdx
    END IF

    RETURN -1
END FUNCTION

' ResetFirstOutGroup: Operator reset once plant conditions are verified safe
SUB ResetFirstOutGroup(grp AS FirstOutGroupRecord)
    grp.IsLatched = 0
    grp.RootCauseIndex = -1
    grp.RootTimestampMs = 0.0
END SUB
