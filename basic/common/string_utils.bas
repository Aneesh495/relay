' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' High-Performance String Formatting & Protocol Hex Utilities
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/common/string_utils.bas
' ==============================================================================
'
' This module implements string manipulation routines required for operator
' console faceplates, hexadecimal frame packet inspection (Modbus/DNP3),
' engineering unit formatting, and token parsing.
' ==============================================================================

' ------------------------------------------------------------------------------
' SECTION 1: PADDING AND ALIGNMENT HELPERS
' ------------------------------------------------------------------------------

' RepeatChar: Returns a string consisting of count repetitions of character ch$
FUNCTION RepeatChar(ch AS STRING, count AS INTEGER) AS STRING
    DIM res AS STRING
    DIM i AS INTEGER
    res = ""
    FOR i = 1 TO count
        res = res + ch
    NEXT i
    RETURN res
END FUNCTION

' PadRight: Aligns text to the left and pads with spaces up to target width
FUNCTION PadRight(src AS STRING, width AS INTEGER) AS STRING
    DIM sLen AS INTEGER
    sLen = LEN(src)
    IF sLen >= width THEN
        RETURN LEFT$(src, width)
    END IF
    RETURN src + RepeatChar(" ", width - sLen)
END FUNCTION

' PadLeft: Aligns text to the right and prepends spaces up to target width
FUNCTION PadLeft(src AS STRING, width AS INTEGER) AS STRING
    DIM sLen AS INTEGER
    sLen = LEN(src)
    IF sLen >= width THEN
        RETURN LEFT$(src, width)
    END IF
    RETURN RepeatChar(" ", width - sLen) + src
END FUNCTION

' CenterText: Centers text within a field of specified width
FUNCTION CenterText(src AS STRING, width AS INTEGER) AS STRING
    DIM sLen AS INTEGER
    sLen = LEN(src)
    IF sLen >= width THEN
        RETURN LEFT$(src, width)
    END IF
    DIM totalPad AS INTEGER : totalPad = width - sLen
    DIM padLeftCount AS INTEGER : padLeftCount = totalPad \ 2
    DIM padRightCount AS INTEGER : padRightCount = totalPad - padLeftCount
    RETURN RepeatChar(" ", padLeftCount) + src + RepeatChar(" ", padRightCount)
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 2: NUMERIC AND ENGINEERING VALUE FORMATTING
' ------------------------------------------------------------------------------

' FormatDouble: Converts a double-precision float to string with fixed decimal places
FUNCTION FormatDouble(val AS DOUBLE, decimals AS INTEGER) AS STRING
    DIM isNeg AS INTEGER : isNeg = 0
    IF val < 0.0 THEN
        isNeg = 1
        val = -val
    END IF

    DIM factor AS DOUBLE : factor = 1.0
    DIM d AS INTEGER
    FOR d = 1 TO decimals
        factor = factor * 10.0
    NEXT d

    DIM rounded AS DOUBLE
    rounded = val * factor + 0.5
    DIM intPart AS INTEGER
    intPart = INT(rounded / factor)

    DIM fracPart AS INTEGER
    fracPart = INT(rounded) - (intPart * INT(factor))

    DIM sInt AS STRING : sInt = STR$(intPart)
    DIM sFrac AS STRING : sFrac = STR$(fracPart)

    ' Pad fractional part with leading zeros if needed
    WHILE LEN(sFrac) < decimals
        sFrac = "0" + sFrac
    WEND

    DIM result AS STRING
    IF decimals > 0 THEN
        result = sInt + "." + sFrac
    ELSE
        result = sInt
    END IF

    IF isNeg = 1 THEN
        result = "-" + result
    END IF

    RETURN result
END FUNCTION

' FormatEngineeringValue: Formats value with engineering unit string and width
FUNCTION FormatEngineeringValue(val AS DOUBLE, units AS STRING, decimals AS INTEGER, width AS INTEGER) AS STRING
    DIM numStr AS STRING
    numStr = FormatDouble(val, decimals)
    DIM fullStr AS STRING
    fullStr = numStr + " " + units
    RETURN PadLeft(fullStr, width)
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 3: HEXADECIMAL AND BYTE CONVERSIONS
' ------------------------------------------------------------------------------

' ByteToHex: Formats an 8-bit integer (0-255) as a 2-character hex string (e.g. "0F")
FUNCTION ByteToHex(b AS INTEGER) AS STRING
    DIM hexChars AS STRING
    hexChars = "0123456789ABCDEF"
    DIM hiNibble AS INTEGER : hiNibble = (b \ 16) AND 15
    DIM loNibble AS INTEGER : loNibble = b AND 15
    RETURN MID$(hexChars, hiNibble + 1, 1) + MID$(hexChars, loNibble + 1, 1)
END FUNCTION

' WordToHex: Formats a 16-bit integer (0-65535) as a 4-character hex string
FUNCTION WordToHex(w AS INTEGER) AS STRING
    DIM hiByte AS INTEGER : hiByte = (w \ 256) AND 255
    DIM loByte AS INTEGER : loByte = w AND 255
    RETURN ByteToHex(hiByte) + ByteToHex(loByte)
END FUNCTION

' HexToByte: Parses a 2-character hex string into an integer (0-255)
FUNCTION HexToByte(hStr AS STRING) AS INTEGER
    IF LEN(hStr) < 2 THEN RETURN 0
    DIM c1 AS STRING : c1 = UCASE$(MID$(hStr, 1, 1))
    DIM c2 AS STRING : c2 = UCASE$(MID$(hStr, 2, 1))
    DIM hexDigits AS STRING : hexDigits = "0123456789ABCDEF"
    DIM v1 AS INTEGER : v1 = INSTR(hexDigits, c1) - 1
    DIM v2 AS INTEGER : v2 = INSTR(hexDigits, c2) - 1
    IF v1 < 0 OR v2 < 0 THEN RETURN 0
    RETURN v1 * 16 + v2
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 4: DELIMITED TOKEN PARSING
' ------------------------------------------------------------------------------

' CountTokens: Counts occurrences of delimiter char inside target string
FUNCTION CountTokens(src AS STRING, delim AS STRING) AS INTEGER
    IF LEN(src) = 0 THEN RETURN 0
    DIM count AS INTEGER : count = 1
    DIM i AS INTEGER
    FOR i = 1 TO LEN(src)
        IF MID$(src, i, 1) = delim THEN
            count = count + 1
        END IF
    NEXT i
    RETURN count
END FUNCTION

' GetToken: Extracts the 1-based index token from a delimited string
FUNCTION GetToken(src AS STRING, delim AS STRING, index AS INTEGER) AS STRING
    DIM currentTok AS INTEGER : currentTok = 1
    DIM startPos AS INTEGER : startPos = 1
    DIM i AS INTEGER

    FOR i = 1 TO LEN(src)
        IF MID$(src, i, 1) = delim THEN
            IF currentTok = index THEN
                RETURN MID$(src, startPos, i - startPos)
            END IF
            currentTok = currentTok + 1
            startPos = i + 1
        END IF
    NEXT i

    IF currentTok = index THEN
        RETURN MID$(src, startPos, LEN(src) - startPos + 1)
    END IF

    RETURN ""
END FUNCTION
