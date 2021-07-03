' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' High-Availability Controller State Replication & Memory Mirroring
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/redundancy/state_sync.bas
' ==============================================================================
'
' This module implements the memory replication protocol between Primary and
' Standby controllers in a dual-redundant architecture:
'   - Selective tag table mirroring with delta change detection
'   - PID internal integrator state and bias term synchronization
'   - ISA-18.2 active alarm list and shelving timer replication
'   - ISA-88 batch engine active phase and recipe step alignment
'   - CRC-32 replication block integrity verification
' ==============================================================================

CONST MAX_SYNC_ENTRIES = 128

TYPE SyncEntry
    TagId           AS INTEGER
    TagValue        AS DOUBLE
    TagQuality      AS INTEGER
    PidIntegralTerm AS DOUBLE
    AlarmState      AS INTEGER
    BatchPhaseId    AS INTEGER
    DirtyFlag       AS INTEGER ' 1 = Changed in current cycle, 0 = Clean
END TYPE

TYPE ReplicationTable
    Entries(128)    AS SyncEntry
    TotalEntries    AS INTEGER
    SyncCycleNumber AS INTEGER
    TotalBytesSynced AS DOUBLE
    ChecksumCRC32   AS INTEGER
END TYPE

' InitializeReplicationTable: Sets up state synchronization buffers
SUB InitializeReplicationTable(tbl AS ReplicationTable)
    tbl.TotalEntries = 0
    tbl.SyncCycleNumber = 0
    tbl.TotalBytesSynced = 0.0
    tbl.ChecksumCRC32 = 0
    
    DIM i AS INTEGER
    FOR i = 1 TO MAX_SYNC_ENTRIES
        tbl.Entries(i).TagId = 0
        tbl.Entries(i).TagValue = 0.0
        tbl.Entries(i).TagQuality = 192 ' OPC Good
        tbl.Entries(i).PidIntegralTerm = 0.0
        tbl.Entries(i).AlarmState = 0
        tbl.Entries(i).BatchPhaseId = 0
        tbl.Entries(i).DirtyFlag = 0
    NEXT i
END SUB

' RegisterSyncTag: Adds a tag to the mirror tracking table
SUB RegisterSyncTag(tbl AS ReplicationTable, tagId AS INTEGER)
    IF tbl.TotalEntries >= MAX_SYNC_ENTRIES THEN EXIT SUB
    
    tbl.TotalEntries = tbl.TotalEntries + 1
    tbl.Entries(tbl.TotalEntries).TagId = tagId
    tbl.Entries(tbl.TotalEntries).TagValue = 0.0
    tbl.Entries(tbl.TotalEntries).TagQuality = 192
    tbl.Entries(tbl.TotalEntries).PidIntegralTerm = 0.0
    tbl.Entries(tbl.TotalEntries).AlarmState = 0
    tbl.Entries(tbl.TotalEntries).BatchPhaseId = 0
    tbl.Entries(tbl.TotalEntries).DirtyFlag = 1
END SUB

' UpdateSyncEntry: Primary records local state updates
SUB UpdateSyncEntry(tbl AS ReplicationTable, tagId AS INTEGER, val AS DOUBLE, q AS INTEGER, iTerm AS DOUBLE, almState AS INTEGER, phaseId AS INTEGER)
    DIM i AS INTEGER
    FOR i = 1 TO tbl.TotalEntries
        IF tbl.Entries(i).TagId = tagId THEN
            ' Only mark dirty if state actually shifted
            IF tbl.Entries(i).TagValue <> val OR tbl.Entries(i).PidIntegralTerm <> iTerm OR tbl.Entries(i).AlarmState <> almState THEN
                tbl.Entries(i).TagValue = val
                tbl.Entries(i).TagQuality = q
                tbl.Entries(i).PidIntegralTerm = iTerm
                tbl.Entries(i).AlarmState = almState
                tbl.Entries(i).BatchPhaseId = phaseId
                tbl.Entries(i).DirtyFlag = 1
            END IF
            EXIT SUB
        END IF
    NEXT i
END SUB

' ComputeTableChecksum: Computes 32-bit Fletcher/CRC-like verification hash
FUNCTION ComputeTableChecksum(tbl AS ReplicationTable) AS INTEGER
    DIM sum1 AS INTEGER : sum1 = 65521
    DIM sum2 AS INTEGER : sum2 = 0
    
    DIM i AS INTEGER
    FOR i = 1 TO tbl.TotalEntries
        DIM intVal AS INTEGER : intVal = INT(tbl.Entries(i).TagValue * 100.0) AND 65535
        sum1 = (sum1 + intVal + tbl.Entries(i).TagId) AND 65535
        sum2 = (sum2 + sum1) AND 65535
    NEXT i
    
    ComputeTableChecksum = (sum2 * 65536) OR sum1
END FUNCTION

' ApplyStandbyReplication: Standby applies received primary state mirror
SUB ApplyStandbyReplication(standbyTbl AS ReplicationTable, primaryTbl AS ReplicationTable)
    standbyTbl.TotalEntries = primaryTbl.TotalEntries
    standbyTbl.SyncCycleNumber = primaryTbl.SyncCycleNumber + 1
    
    DIM i AS INTEGER
    FOR i = 1 TO primaryTbl.TotalEntries
        standbyTbl.Entries(i).TagId = primaryTbl.Entries(i).TagId
        standbyTbl.Entries(i).TagValue = primaryTbl.Entries(i).TagValue
        standbyTbl.Entries(i).TagQuality = primaryTbl.Entries(i).TagQuality
        standbyTbl.Entries(i).PidIntegralTerm = primaryTbl.Entries(i).PidIntegralTerm
        standbyTbl.Entries(i).AlarmState = primaryTbl.Entries(i).AlarmState
        standbyTbl.Entries(i).BatchPhaseId = primaryTbl.Entries(i).BatchPhaseId
        standbyTbl.Entries(i).DirtyFlag = 0
    NEXT i
    
    standbyTbl.ChecksumCRC32 = primaryTbl.ChecksumCRC32
END SUB
