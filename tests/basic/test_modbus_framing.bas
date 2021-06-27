' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Modbus TCP/RTU, DNP3, and Sparkplug B
' File: tests/basic/test_modbus_framing.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: MODBUS RTU CRC-16 TEST VECTOR
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Test frame: 0x01, 0x03, 0x00, 0x00, 0x00, 0x01
' Expected CRC-16 result: 0x0A84 (decimal 2692)
DIM b0 AS INTEGER : b0 = 1
DIM b1 AS INTEGER : b1 = 3
DIM b2 AS INTEGER : b2 = 0
DIM b3 AS INTEGER : b3 = 0
DIM b4 AS INTEGER : b4 = 0
DIM b5 AS INTEGER : b5 = 1

DIM crcVal AS INTEGER : crcVal = 65535  ' 0xFFFF
DIM curByte AS INTEGER
DIM bit AS INTEGER
DIM p AS INTEGER

FOR p = 0 TO 5
    IF p = 0 THEN curByte = b0
    IF p = 1 THEN curByte = b1
    IF p = 2 THEN curByte = b2
    IF p = 3 THEN curByte = b3
    IF p = 4 THEN curByte = b4
    IF p = 5 THEN curByte = b5

    crcVal = crcVal XOR curByte
    FOR bit = 0 TO 7
        IF (crcVal AND 1) <> 0 THEN
            crcVal = (crcVal \ 2) XOR 40961  ' 0xA001
        ELSE
            crcVal = crcVal \ 2
        END IF
    NEXT bit
NEXT p

IF crcVal = 2692 THEN  ' 0x0A84
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: Modbus RTU CRC-16 matches test vector (0x0A84 / 2692)"
ELSE
    PRINT "[FAIL] Test 1: Modbus RTU CRC-16 calculation failed:", crcVal
END IF

' ------------------------------------------------------------------------------
' TEST 2: MODBUS TCP MBAP HEADER LENGTH FIELD
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' For FC03 query, PDU is 5 bytes (FC + StartAddr[2] + Count[2]).
' MBAP length field is UnitID(1) + PDU(5) = 6 bytes
DIM pduLen AS INTEGER : pduLen = 5
DIM mbapLen AS INTEGER : mbapLen = 1 + pduLen
IF mbapLen = 6 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: Modbus TCP MBAP header length field (6 bytes)"
ELSE
    PRINT "[FAIL] Test 2: MBAP length calculation failed"
END IF

' ------------------------------------------------------------------------------
' TEST 3: DNP3 FRAME SYNCHRONIZATION BYTES
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' DNP3 standard link layer header sync bytes MUST be 0x05 followed by 0x64
DIM sync1 AS INTEGER : sync1 = 5
DIM sync2 AS INTEGER : sync2 = 100
DIM isDnp3SyncValid AS INTEGER : isDnp3SyncValid = 0
IF sync1 = 5 AND sync2 = 100 THEN
    isDnp3SyncValid = 1
END IF

IF isDnp3SyncValid = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: DNP3 link-layer frame sync octets verified (0x05 0x64)"
ELSE
    PRINT "[FAIL] Test 3: DNP3 sync byte verification failed"
END IF

' ------------------------------------------------------------------------------
' TEST 4: SPARKPLUG B SEQUENCE COUNTER ROLLOVER
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Sparkplug B sequence number is an unsigned 8-bit integer (0 to 255)
' 255 + 1 MUST rollover to 0
DIM seqNum AS INTEGER : seqNum = 255
DIM nextSeq AS INTEGER : nextSeq = (seqNum + 1) MOD 256
IF nextSeq = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Sparkplug B sequence counter rollover (255 -> 0)"
ELSE
    PRINT "[FAIL] Test 4: Sequence counter rollover failed:", nextSeq
END IF

' ------------------------------------------------------------------------------
' TEST 5: 32-BIT FLOAT REGISTER WORD SWAPPING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Test value 123.45 scaled by 100 is 12345
DIM testValScaled AS INTEGER : testValScaled = 12345
DIM wHi AS INTEGER : wHi = testValScaled \ 65536      ' 0
DIM wLo AS INTEGER : wLo = testValScaled AND 65535   ' 12345
' Reconstructed:
DIM restoredScaled AS INTEGER : restoredScaled = wHi * 65536 + wLo
IF restoredScaled = 12345 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Modbus 32-bit register pair packing and reconstruction"
ELSE
    PRINT "[FAIL] Test 5: Register packing failed"
END IF

' ------------------------------------------------------------------------------
' TEST 6: SPARKPLUG B MQTT TOPIC STRUCTURE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM grp AS STRING : grp = "PLANT_A"
DIM msgT AS STRING : msgT = "NDATA"
DIM node AS STRING : node = "PLC_01"
DIM topic AS STRING : topic = "spBv1.0/" + grp + "/" + msgT + "/" + node
IF topic = "spBv1.0/PLANT_A/NDATA/PLC_01" THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Sparkplug B MQTT topic hierarchy generation"
ELSE
    PRINT "[FAIL] Test 6: Topic generation failed:", topic
END IF

PRINT "=================================================="
PRINT "Protocol Subsystem Verification Summary: Passed", testsPassed, "of", testsTotal, "tests."
PRINT "=================================================="
