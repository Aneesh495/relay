' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Sparkplug B / MQTT Industrial IoT Telemetry Framing
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/protocols/sparkplug.bas
' ==============================================================================
'
' This module implements Sparkplug B edge telemetry payload formatting.
' It manages message types (NBIRTH, NDATA, DBIRTH, DDATA), sequence counters,
' and metric property serializations.
' ==============================================================================

CONST SPARKPLUG_MSG_NBIRTH = 1
CONST SPARKPLUG_MSG_NDATA  = 2
CONST SPARKPLUG_MSG_DBIRTH = 3
CONST SPARKPLUG_MSG_DDATA  = 4
CONST SPARKPLUG_MSG_DDEATH = 5

' SparkplugSessionTracker: Manages sequence counter and session state
TYPE SparkplugSessionTracker
    GroupId         AS STRING   ' Enterprise group ID (e.g., REFINERY_UNIT_1)
    EdgeNodeId      AS STRING   ' Edge device ID (e.g., SOFT_PLC_01)
    SequenceCounter AS INTEGER  ' Monotonically increasing sequence number 0-255
    IsOnline        AS INTEGER  ' 1 if NBIRTH has been published
END TYPE

' InitializeSparkplugSession: Resets sequence counter
SUB InitializeSparkplugSession(sess AS SparkplugSessionTracker, grpId AS STRING, nodeId AS STRING)
    sess.GroupId = grpId
    sess.EdgeNodeId = nodeId
    sess.SequenceCounter = 0
    sess.IsOnline = 1
END SUB

' GetNextSequenceNumber: Returns current sequence number and increments with 0-255 rollover
FUNCTION GetNextSequenceNumber(sess AS SparkplugSessionTracker) AS INTEGER
    DIM seq AS INTEGER : seq = sess.SequenceCounter
    sess.SequenceCounter = (sess.SequenceCounter + 1) MOD 256
    RETURN seq
END FUNCTION

' BuildSparkplugTopic: Constructs standard MQTT topic namespace:
' spBv1.0 / GroupId / MessageType / EdgeNodeId [ / DeviceId ]
FUNCTION BuildSparkplugTopic(groupId AS STRING, msgType AS INTEGER, nodeId AS STRING) AS STRING
    DIM sType AS STRING
    IF msgType = SPARKPLUG_MSG_NBIRTH THEN sType = "NBIRTH"
    IF msgType = SPARKPLUG_MSG_NDATA THEN sType = "NDATA"
    IF msgType = SPARKPLUG_MSG_DBIRTH THEN sType = "DBIRTH"
    IF msgType = SPARKPLUG_MSG_DDATA THEN sType = "DDATA"
    IF msgType = SPARKPLUG_MSG_DDEATH THEN sType = "DDEATH"

    RETURN "spBv1.0/" + groupId + "/" + sType + "/" + nodeId
END FUNCTION
