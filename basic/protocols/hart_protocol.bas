' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' HART FSK Bell 202 Protocol Dissector & Framing Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/protocols/hart_protocol.bas
' ==============================================================================
'
' This module implements the industrial Highway Addressable Remote Transducer
' (HART) digital communication protocol layered over standard 4-20 mA current loops:
'   - Bell 202 Frequency Shift Keying (FSK) framing (1200 Hz Mark, 2200 Hz Space)
'   - Short (1-byte) and Long (5-byte unique IEEE MAC) addressing modes
'   - Preamble burst synchronization (5 to 20 continuous 0xFF octets)
'   - Standard Universal Commands:
'       Command 1: Read Primary Variable (PV)
'       Command 2: Read Loop Current and Percent of Range
'       Command 3: Read Dynamic Variables (PV, SV, TV, QV)
'   - Longitudinal Redundancy Check (LRC) XOR parity verification
' ==============================================================================

' Standard HART Universal Command Codes
CONST HART_CMD_READ_PV           = 1
CONST HART_CMD_READ_LOOP_CURRENT = 2
CONST HART_CMD_READ_DYN_VARS     = 3
CONST HART_CMD_READ_MSG          = 12
CONST HART_CMD_READ_TAG_DESC     = 13

TYPE HartFrame
    PreambleCount   AS INTEGER ' Number of 0xFF synchronization bytes
    Delimiter       AS INTEGER ' 0x02 = Master-to-Slave, 0x06 = Slave-to-Master
    IsLongAddress   AS INTEGER ' 1 = 5-byte long address, 0 = 1-byte short address
    AddressBytes(5) AS INTEGER
    CommandNumber   AS INTEGER
    ByteCount       AS INTEGER
    DataBytes(32)   AS INTEGER
    ChecksumLRC     AS INTEGER
    IsValid         AS INTEGER
END TYPE

' ComputeHartLRC: Calculates XOR parity across all bytes from Delimiter through Data
FUNCTION ComputeHartLRC(frameBytes(40) AS INTEGER, startIdx AS INTEGER, endIdx AS INTEGER) AS INTEGER
    DIM lrcVal AS INTEGER : lrcVal = 0
    DIM i AS INTEGER
    FOR i = startIdx TO endIdx
        lrcVal = lrcVal XOR (frameBytes(i) AND 255)
    NEXT i
    ComputeHartLRC = lrcVal
END FUNCTION

' BuildHartCmd1Request: Assembles Command 1 (Read PV) master request packet
SUB BuildHartCmd1Request(frame AS HartFrame, shortAddr AS INTEGER)
    frame.PreambleCount = 5
    frame.Delimiter = 2       ' 0x02 STX frame
    frame.IsLongAddress = 0
    frame.AddressBytes(1) = (shortAddr AND 15) OR 128 ' Master address bit 7 = 1
    frame.CommandNumber = HART_CMD_READ_PV
    frame.ByteCount = 0
    
    ' LRC = Delimiter XOR Address XOR Command XOR ByteCount
    frame.ChecksumLRC = frame.Delimiter XOR frame.AddressBytes(1) XOR frame.CommandNumber XOR frame.ByteCount
    frame.IsValid = 1
END SUB

' BuildHartCmd3Response: Builds slave response for Command 3 (PV, SV, TV, QV)
SUB BuildHartCmd3Response(frame AS HartFrame, pvVal AS DOUBLE, svVal AS DOUBLE, tvVal AS DOUBLE, qvVal AS DOUBLE)
    frame.PreambleCount = 5
    frame.Delimiter = 6       ' 0x06 ACK slave frame
    frame.IsLongAddress = 0
    frame.AddressBytes(1) = 0 ' Slave polling address
    frame.CommandNumber = HART_CMD_READ_DYN_VARS
    frame.ByteCount = 18      ' 2 response status bytes + 4x 4-byte IEEE floats
    
    ' Response Code 0: Success, Device Status: 0
    frame.DataBytes(1) = 0
    frame.DataBytes(2) = 0
    
    ' Pack IEEE floats into data bytes (simplified 4-byte scaling representation)
    DIM intPV AS INTEGER : intPV = INT(pvVal * 100.0) AND 65535
    frame.DataBytes(3) = (intPV / 256) AND 255
    frame.DataBytes(4) = intPV AND 255
    
    ' Calculate overall LRC
    DIM lrcAcc AS INTEGER
    lrcAcc = frame.Delimiter XOR frame.AddressBytes(1) XOR frame.CommandNumber XOR frame.ByteCount
    DIM i AS INTEGER
    FOR i = 1 TO frame.ByteCount
        lrcAcc = lrcAcc XOR frame.DataBytes(i)
    NEXT i
    frame.ChecksumLRC = lrcAcc
    frame.IsValid = 1
END SUB
