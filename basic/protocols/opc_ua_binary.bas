' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' OPC Unified Architecture (IEC 62541) Binary TCP Protocol Dissector
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/protocols/opc_ua_binary.bas
' ==============================================================================
'
' This module implements the binary TCP transmission framing for the OPC UA
' industrial interoperability standard (IEC 62541-6):
'   - 3-byte Message Type identifier: "HEL", "ACK", "ERR", "OPN", "MSG", "CLO"
'   - 1-byte Chunk Type: 'F' (Final), 'C' (Continuation), 'A' (Abort)
'   - 4-byte Little-Endian message size header
'   - Symmetric and asymmetric Secure Channel token header framing
'   - NodeId identifier parsing across Numeric and String identifier formats
' ==============================================================================

TYPE OpcUaTcpHeader
    MessageType     AS STRING  ' "HEL", "ACK", "OPN", "MSG", "CLO"
    ChunkType       AS STRING  ' "F", "C", "A"
    MessageSize     AS INTEGER ' Total frame size including 8-byte header
    SecureChannelId AS INTEGER
    SecurityTokenId AS INTEGER
    SequenceNumber  AS INTEGER
    RequestId       AS INTEGER
END TYPE

' BuildOpcUaHelloFrame: Encodes standard UA TCP Hello handshake packet
SUB BuildOpcUaHelloFrame(hdr AS OpcUaTcpHeader, receiveBufferSize AS INTEGER, maxMessageSize AS INTEGER)
    hdr.MessageType = "HEL"
    hdr.ChunkType = "F"
    hdr.MessageSize = 32      ' 8 bytes header + 24 bytes HEL payload
    hdr.SecureChannelId = 0
    hdr.SecurityTokenId = 0
    hdr.SequenceNumber = 1
    hdr.RequestId = 1
END SUB

' BuildOpcUaAckFrame: Encodes UA TCP Acknowledge response packet
SUB BuildOpcUaAckFrame(hdr AS OpcUaTcpHeader, negotiatedBuffer AS INTEGER)
    hdr.MessageType = "ACK"
    hdr.ChunkType = "F"
    hdr.MessageSize = 28      ' 8 bytes header + 20 bytes ACK payload
    hdr.SecureChannelId = 0
    hdr.SecurityTokenId = 0
    hdr.SequenceNumber = 1
    hdr.RequestId = 1
END SUB

' DissectOpcUaHeader: Validates and unpacks 8-byte binary frame header
FUNCTION DissectOpcUaHeader(hdrBytes(8) AS INTEGER, hdr AS OpcUaTcpHeader) AS INTEGER
    ' Byte 0..2: ASCII Message Type
    DIM ch0 AS INTEGER : ch0 = hdrBytes(1)
    DIM ch1 AS INTEGER : ch1 = hdrBytes(2)
    DIM ch2 AS INTEGER : ch2 = hdrBytes(3)
    
    ' Byte 3: Chunk Type ('F'=70, 'C'=67, 'A'=65)
    DIM ch3 AS INTEGER : ch3 = hdrBytes(4)
    IF ch3 = 70 THEN
        hdr.ChunkType = "F"
    ELSEIF ch3 = 67 THEN
        hdr.ChunkType = "C"
    ELSEIF ch3 = 65 THEN
        hdr.ChunkType = "A"
    ELSE
        DissectOpcUaHeader = 0 ' Unknown chunk
        EXIT FUNCTION
    END IF
    
    ' Bytes 4..7: 32-bit Little-Endian Message Size
    DIM b0 AS INTEGER : b0 = hdrBytes(5) AND 255
    DIM b1 AS INTEGER : b1 = hdrBytes(6) AND 255
    DIM b2 AS INTEGER : b2 = hdrBytes(7) AND 255
    DIM b3 AS INTEGER : b3 = hdrBytes(8) AND 255
    
    hdr.MessageSize = b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
    
    ' Validate minimum frame size (at least 8 bytes header)
    IF hdr.MessageSize >= 8 AND hdr.MessageSize <= 67108864 THEN
        DissectOpcUaHeader = 1
    ELSE
        DissectOpcUaHeader = 0
    END IF
END FUNCTION
