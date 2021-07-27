' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' CANopen (CiA 301) Fieldbus Protocol Dissector & SDO/PDO Framer
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/protocols/canopen.bas
' ==============================================================================
'
' This module implements the CANopen industrial fieldbus protocol (CiA 301 / EN 50325-4):
'   - 11-bit COB-ID message routing (Function Code 4-bit + Node ID 7-bit)
'   - NMT Network Management broadcast and heartbeat states
'   - Service Data Object (SDO) expedited read/write dictionary access
'   - Process Data Object (PDO) high-speed cyclical process data mapping
' ==============================================================================

' Standard CANopen Function Codes (shifted by 7 bits)
CONST CANOPEN_FUNC_NMT       = 0     ' COB-ID 0x000
CONST CANOPEN_FUNC_SYNC      = 128   ' COB-ID 0x080
CONST CANOPEN_FUNC_TPDO1     = 384   ' COB-ID 0x180 + NodeId
CONST CANOPEN_FUNC_RPDO1     = 512   ' COB-ID 0x200 + NodeId
CONST CANOPEN_FUNC_TPDO2     = 640   ' COB-ID 0x280 + NodeId
CONST CANOPEN_FUNC_RPDO2     = 768   ' COB-ID 0x300 + NodeId
CONST CANOPEN_FUNC_TSDO      = 1408  ' COB-ID 0x580 + NodeId (SDO Response)
CONST CANOPEN_FUNC_RSDO      = 1536  ' COB-ID 0x600 + NodeId (SDO Request)
CONST CANOPEN_FUNC_HEARTBEAT = 1792  ' COB-ID 0x700 + NodeId

' SDO Command Specifiers
CONST SDO_CMD_READ_EXPEDITED  = 64   ' 0x40 Initiate Upload
CONST SDO_CMD_WRITE_EXPEDITED = 35   ' 0x23 Initiate Download (4 bytes)
CONST SDO_RESP_WRITE_SUCCESS  = 96   ' 0x60 Download response
CONST SDO_RESP_ABORT          = 128  ' 0x80 Abort transfer

TYPE CanopenFrame
    CobId           AS INTEGER ' 11-bit CAN Identifier
    FunctionCode    AS INTEGER ' Extracted function code
    NodeId          AS INTEGER ' Extracted node ID (1 to 127)
    DlcLength       AS INTEGER ' Data length code (0 to 8 bytes)
    DataBytes(8)    AS INTEGER
END TYPE

' BuildCanopenSdoReadRequest: Builds SDO Upload Request for object dictionary index
SUB BuildCanopenSdoReadRequest(frame AS CanopenFrame, nodeId AS INTEGER, objIndex AS INTEGER, subIndex AS INTEGER)
    frame.NodeId = nodeId AND 127
    frame.FunctionCode = CANOPEN_FUNC_RSDO
    frame.CobId = CANOPEN_FUNC_RSDO + frame.NodeId
    frame.DlcLength = 8
    
    ' Byte 0: 0x40 (Initiate Upload)
    frame.DataBytes(1) = SDO_CMD_READ_EXPEDITED
    ' Bytes 1..2: 16-bit Index (Little-Endian)
    frame.DataBytes(2) = objIndex AND 255
    frame.DataBytes(3) = (objIndex / 256) AND 255
    ' Byte 3: Subindex
    frame.DataBytes(4) = subIndex AND 255
    ' Bytes 4..7: Reserved zeros
    frame.DataBytes(5) = 0
    frame.DataBytes(6) = 0
    frame.DataBytes(7) = 0
    frame.DataBytes(8) = 0
END SUB

' BuildCanopenHeartbeat: Builds NMT node guarding heartbeat frame
SUB BuildCanopenHeartbeat(frame AS CanopenFrame, nodeId AS INTEGER, nmtState AS INTEGER)
    frame.NodeId = nodeId AND 127
    frame.FunctionCode = CANOPEN_FUNC_HEARTBEAT
    frame.CobId = CANOPEN_FUNC_HEARTBEAT + frame.NodeId
    frame.DlcLength = 1
    frame.DataBytes(1) = nmtState ' 0x05 = Operational, 0x7F = Pre-operational
END SUB

' DissectCanopenCobId: Parses 11-bit COB-ID into functional components
SUB DissectCanopenCobId(cobId AS INTEGER, funcCode AS INTEGER, nodeId AS INTEGER)
    nodeId = cobId AND 127
    funcCode = cobId AND 1920 ' Bits 7..10
END SUB
