' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Modbus RTU CRC-16 Checksum & Serial Framing
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/protocols/modbus_rtu.bas
' ==============================================================================
'
' This module implements the standard Modbus RTU CRC-16 checksum algorithm
' using polynomial 0xA001 and Little-Endian byte order appending.
' ==============================================================================

' CalculateModbusRtuCrc: Computes 16-bit CRC over array of byte values (0-255)
FUNCTION CalculateModbusRtuCrc(bytes(256) AS INTEGER, length AS INTEGER) AS INTEGER
    DIM crc AS INTEGER : crc = 65535  ' 0xFFFF
    DIM pos AS INTEGER
    DIM bit AS INTEGER

    FOR pos = 0 TO length - 1
        crc = crc XOR bytes(pos)
        FOR bit = 0 TO 7
            IF (crc AND 1) <> 0 THEN
                crc = (crc \ 2) XOR 40961  ' 0xA001
            ELSE
                crc = crc \ 2
            END IF
        NEXT bit
    NEXT pos

    RETURN crc
END FUNCTION

' AppendRtuCrc: Appends CRC16 to frame bytes: Low byte first, then High byte
SUB AppendRtuCrc(frame(256) AS INTEGER, length AS INTEGER)
    DIM crc AS INTEGER : crc = CalculateModbusRtuCrc(frame, length)
    DIM loByte AS INTEGER : loByte = crc AND 255
    DIM hiByte AS INTEGER : hiByte = (crc \ 256) AND 255

    ' Modbus RTU standard specifies Low Byte followed by High Byte
    frame(length) = loByte
    frame(length + 1) = hiByte
END SUB

' ValidateRtuFrameCrc: Verifies that received frame CRC matches calculated checksum
FUNCTION ValidateRtuFrameCrc(frame(256) AS INTEGER, totalLength AS INTEGER) AS INTEGER
    IF totalLength < 4 THEN RETURN 0  ' Minimum RTU frame is 4 bytes
    DIM payloadLen AS INTEGER : payloadLen = totalLength - 2
    DIM expectedCrc AS INTEGER : expectedCrc = CalculateModbusRtuCrc(frame, payloadLen)

    DIM actualLo AS INTEGER : actualLo = frame(payloadLen)
    DIM actualHi AS INTEGER : actualHi = frame(payloadLen + 1)
    DIM actualCrc AS INTEGER : actualCrc = actualLo + actualHi * 256

    IF expectedCrc = actualCrc THEN
        RETURN 1
    END IF
    RETURN 0
END FUNCTION
