' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Dual-Redundant Controller Heartbeat & Peer Health Supervisor
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/redundancy/heartbeat.bas
' ==============================================================================
'
' This module implements the fault-tolerant heartbeat and failure detection
' state machine for 1:1 warm and hot standby dual-controller pairs:
'   - High-speed peer heartbeat frame exchange (nominal 20 ms period)
'   - Sliding window heartbeat loss detector with configurable trip threshold
'   - Controller hardware self-health scoring and watchdog monitoring
'   - Deterministic role arbitration to prevent split-brain conditions
' ==============================================================================

' Controller Operational Roles
CONST ROLE_OFFLINE   = 0
CONST ROLE_STANDBY   = 1
CONST ROLE_PRIMARY   = 2
CONST ROLE_FAILED    = 3

' Health Status
CONST HEALTH_OK      = 0
CONST HEALTH_DEGRADED = 1
CONST HEALTH_CRITICAL = 2

TYPE HeartbeatPacket
    SenderNodeId     AS INTEGER ' 1 = Controller A, 2 = Controller B
    CurrentRole      AS INTEGER ' ROLE_PRIMARY, ROLE_STANDBY, etc.
    SequenceNumber   AS INTEGER ' Rolling sequence counter (0 to 65535)
    TimestampMicros  AS DOUBLE  ' High-resolution send timestamp
    HealthScore      AS INTEGER ' 0 (Healthy) to 100 (Unhealthy)
    ScanCycleTimeMs  AS DOUBLE  ' Execution time of last control scan cycle
    SyncChecksum     AS INTEGER ' Checksum of synchronized tag database
END TYPE

TYPE RedundancySupervisor
    LocalNodeId      AS INTEGER ' 1 for Node A, 2 for Node B
    LocalRole        AS INTEGER ' ROLE_PRIMARY, ROLE_STANDBY, etc.
    LocalHealth      AS INTEGER ' HEALTH_OK, DEGRADED, CRITICAL
    LocalSeqCounter  AS INTEGER
    
    PeerRole         AS INTEGER
    PeerLastSeq      AS INTEGER
    PeerLastSeenTime AS DOUBLE  ' Timestamp of last valid received heartbeat
    PeerMissedBeats  AS INTEGER ' Consecutive missed heartbeats
    PeerTimeoutMs    AS DOUBLE  ' Failover timeout threshold (e.g. 60.0 ms)
    
    IsSplitBrainRisk AS INTEGER ' 1 if both nodes attempt PRIMARY role
    FailoverCount    AS INTEGER ' Total failovers executed
END TYPE

' InitializeRedundancySupervisor: Sets initial node identity and role
SUB InitializeRedundancySupervisor(sup AS RedundancySupervisor, nodeId AS INTEGER, initialRole AS INTEGER)
    sup.LocalNodeId = nodeId
    sup.LocalRole = initialRole
    sup.LocalHealth = HEALTH_OK
    sup.LocalSeqCounter = 0
    
    IF initialRole = ROLE_PRIMARY THEN
        sup.PeerRole = ROLE_STANDBY
    ELSE
        sup.PeerRole = ROLE_PRIMARY
    END IF
    
    sup.PeerLastSeq = 0
    sup.PeerLastSeenTime = 0.0
    sup.PeerMissedBeats = 0
    sup.PeerTimeoutMs = 60.0    ' 3 consecutive 20 ms drops trigger failover
    sup.IsSplitBrainRisk = 0
    sup.FailoverCount = 0
END SUB

' BuildHeartbeatPacket: Assembles outgoing packet with local telemetry
SUB BuildHeartbeatPacket(sup AS RedundancySupervisor, pkt AS HeartbeatPacket, currentTimeUs AS DOUBLE, scanMs AS DOUBLE, checksum AS INTEGER)
    sup.LocalSeqCounter = (sup.LocalSeqCounter + 1) AND 65535
    
    pkt.SenderNodeId = sup.LocalNodeId
    pkt.CurrentRole = sup.LocalRole
    pkt.SequenceNumber = sup.LocalSeqCounter
    pkt.TimestampMicros = currentTimeUs
    
    IF sup.LocalHealth = HEALTH_OK THEN
        pkt.HealthScore = 0
    ELSEIF sup.LocalHealth = HEALTH_DEGRADED THEN
        pkt.HealthScore = 50
    ELSE
        pkt.HealthScore = 100
    END IF
    
    pkt.ScanCycleTimeMs = scanMs
    pkt.SyncChecksum = checksum
END SUB

' ProcessPeerHeartbeat: Ingests incoming peer heartbeat and updates watchdog
SUB ProcessPeerHeartbeat(sup AS RedundancySupervisor, pkt AS HeartbeatPacket, currentTimeUs AS DOUBLE)
    ' Validate packet source
    IF pkt.SenderNodeId = sup.LocalNodeId THEN
        ' Loopback packet ignored
        EXIT SUB
    END IF
    
    sup.PeerRole = pkt.CurrentRole
    sup.PeerLastSeq = pkt.SequenceNumber
    sup.PeerLastSeenTime = currentTimeUs
    sup.PeerMissedBeats = 0
    
    ' Split-brain arbitration: if both claim PRIMARY, lower NodeId wins tie-break
    IF sup.LocalRole = ROLE_PRIMARY AND pkt.CurrentRole = ROLE_PRIMARY THEN
        sup.IsSplitBrainRisk = 1
        IF sup.LocalNodeId > pkt.SenderNodeId THEN
            ' Yield primary role to lower Node ID
            sup.LocalRole = ROLE_STANDBY
            sup.FailoverCount = sup.FailoverCount + 1
        END IF
    ELSE
        sup.IsSplitBrainRisk = 0
    END IF
END SUB

' EvaluateRedundancyWatchdog: Periodic evaluation (called every scan cycle)
SUB EvaluateRedundancyWatchdog(sup AS RedundancySupervisor, currentTimeUs AS DOUBLE, dtMs AS DOUBLE)
    ' Check peer elapsed silence time
    DIM elapsedSincePeerMs AS DOUBLE
    elapsedSincePeerMs = (currentTimeUs - sup.PeerLastSeenTime) / 1000.0
    
    IF elapsedSincePeerMs > sup.PeerTimeoutMs THEN
        sup.PeerMissedBeats = sup.PeerMissedBeats + 1
        
        ' If peer was primary and timed out, and local node is standby and healthy: promote!
        IF sup.PeerRole = ROLE_PRIMARY AND sup.LocalRole = ROLE_STANDBY THEN
            IF sup.LocalHealth <> HEALTH_CRITICAL THEN
                sup.LocalRole = ROLE_PRIMARY
                sup.PeerRole = ROLE_FAILED
                sup.FailoverCount = sup.FailoverCount + 1
            END IF
        END IF
    END IF
    
    ' Local health downgrade check
    IF sup.LocalHealth = HEALTH_CRITICAL AND sup.LocalRole = ROLE_PRIMARY THEN
        ' Demote local node if peer is available
        IF sup.PeerMissedBeats < 3 AND sup.PeerRole = ROLE_STANDBY THEN
            sup.LocalRole = ROLE_STANDBY
            sup.FailoverCount = sup.FailoverCount + 1
        END IF
    END IF
END SUB
