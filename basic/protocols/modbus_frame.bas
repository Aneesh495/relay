' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Modbus TCP Protocol Application Framing Engine (MBAP)
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/protocols/modbus_frame.bas
' ==============================================================================
'
' This module implements the Modbus Application Protocol (MBAP) header and
' Application Data Unit (ADU) framing for Modbus TCP/IP (port 502):
'   Bytes 0-1: Transaction Identifier (echoed by server)
'   Bytes 2-3: Protocol Identifier (always 0x0000 for Modbus)
'   Bytes 4-5: Length Field (number of following bytes: unit ID + PDU)
'   Byte 6:    Unit Identifier (remote slave station address 1-247)
'   Byte 7:    Function Code (01, 02, 03, 04, 05, 06, 15, 16)
'   Bytes 8+:  Data Payload (address, count, byte count, register values)
' ==============================================================================

CONST MODBUS_PROTO_TCP = 0

' EncodeMbapHeader: Constructs 7-byte MBAP header string in hex notation
FUNCTION EncodeMbapHeader(transId AS INTEGER, unitId AS INTEGER, pduLength AS INTEGER) AS STRING
    DIM hexTrans AS STRING : hexTrans = WordToHex(transId)
    DIM hexProto AS STRING : hexProto = WordToHex(MODBUS_PROTO_TCP)
    DIM totalLen AS INTEGER : totalLen = 1 + pduLength  ' UnitID + PDU
    DIM hexLen AS STRING : hexLen = WordToHex(totalLen)
    DIM hexUnit AS STRING : hexUnit = ByteToHex(unitId)

    RETURN hexTrans + hexProto + hexLen + hexUnit
END FUNCTION

' BuildReadHoldingRegistersAdu: Assembles complete Function Code 03 query ADU
FUNCTION BuildReadHoldingRegistersAdu(transId AS INTEGER, unitId AS INTEGER, startAddr AS INTEGER, count AS INTEGER) AS STRING
    DIM mbap AS STRING : mbap = EncodeMbapHeader(transId, unitId, 5)  ' PDU is 5 bytes: FC(1) + Addr(2) + Count(2)
    DIM hexFc AS STRING : hexFc = ByteToHex(3)                        ' Function code 03
    DIM hexAddr AS STRING : hexAddr = WordToHex(startAddr)
    DIM hexCount AS STRING : hexCount = WordToHex(count)

    RETURN mbap + hexFc + hexAddr + hexCount
END FUNCTION

' BuildWriteSingleRegisterAdu: Assembles complete Function Code 06 command ADU
FUNCTION BuildWriteSingleRegisterAdu(transId AS INTEGER, unitId AS INTEGER, regAddr AS INTEGER, regValue AS INTEGER) AS STRING
    DIM mbap AS STRING : mbap = EncodeMbapHeader(transId, unitId, 5)  ' PDU is 5 bytes: FC(1) + Addr(2) + Val(2)
    DIM hexFc AS STRING : hexFc = ByteToHex(6)                        ' Function code 06
    DIM hexAddr AS STRING : hexAddr = WordToHex(regAddr)
    DIM hexVal AS STRING : hexVal = WordToHex(regValue)

    RETURN mbap + hexFc + hexAddr + hexVal
END FUNCTION
