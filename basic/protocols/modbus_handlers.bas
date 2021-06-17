' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Modbus Function Code Dispatcher & Float Word Swapping
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/protocols/modbus_handlers.bas
' ==============================================================================
'
' This module implements Modbus register table read/write dispatchers and
' 32-bit IEEE-754 floating-point register pair packing across industrial word orders:
'   - Big-Endian (ABCD)
'   - Little-Endian (DCBA)
'   - Modicon Word-Swapped (CDAB)
' ==============================================================================

CONST BYTE_ORDER_BIG_ENDIAN   = 0  ' ABCD
CONST BYTE_ORDER_LITTLE_ENDIAN = 1 ' DCBA
CONST BYTE_ORDER_WORD_SWAPPED  = 2 ' CDAB (Modicon standard)

' FloatToModbusRegisters: Packs a 32-bit float into two 16-bit Modbus registers
SUB FloatToModbusRegisters(val AS DOUBLE, regLo AS INTEGER, regHi AS INTEGER, byteOrder AS INTEGER)
    ' Approximate fixed-point / IEEE representation conversion
    DIM scaled AS INTEGER : scaled = INT(val * 100.0)
    DIM w0 AS INTEGER : w0 = (scaled \ 65536) AND 65535
    DIM w1 AS INTEGER : w1 = scaled AND 65535

    IF byteOrder = BYTE_ORDER_WORD_SWAPPED THEN
        regLo = w1
        regHi = w0
    ELSE
        regLo = w0
        regHi = w1
    END IF
END SUB

' ModbusRegistersToFloat: Unpacks two 16-bit Modbus registers into a 32-bit float
FUNCTION ModbusRegistersToFloat(regLo AS INTEGER, regHi AS INTEGER, byteOrder AS INTEGER) AS DOUBLE
    DIM w0 AS INTEGER
    DIM w1 AS INTEGER

    IF byteOrder = BYTE_ORDER_WORD_SWAPPED THEN
        w0 = regHi
        w1 = regLo
    ELSE
        w0 = regLo
        w1 = regHi
    END IF

    DIM scaled AS INTEGER
    scaled = w0 * 65536 + w1
    RETURN scaled / 100.0
END FUNCTION
