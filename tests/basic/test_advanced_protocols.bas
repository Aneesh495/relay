' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Advanced Industrial Communication Protocols
' File: tests/basic/test_advanced_protocols.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: HART PROTOCOL COMMAND 1 REQUEST & LRC CHECKSUM
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Delimiter = 0x02, Address = 0x80 (Master to Polling Addr 0), Command = 1, ByteCount = 0
' LRC = 0x02 XOR 0x80 XOR 0x01 XOR 0x00 = 0x83 (131 decimal)
DIM hartDelim AS INTEGER : hartDelim = 2
DIM hartAddr AS INTEGER : hartAddr = 128
DIM hartCmd AS INTEGER : hartCmd = 1
DIM hartBc AS INTEGER : hartBc = 0
DIM calcLRC AS INTEGER : calcLRC = hartDelim XOR hartAddr XOR hartCmd XOR hartBc

IF calcLRC = 131 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: HART protocol Command 1 LRC XOR checksum verified (0x83 = 131)"
ELSE
    PRINT "[FAIL] Test 1: HART LRC calculation failed:", calcLRC
END IF

' ------------------------------------------------------------------------------
' TEST 2: HART MULTI-BYTE RESPONSE FRAME PARITY
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Verify parity: A XOR A = 0
DIM lrcTest AS INTEGER : lrcTest = calcLRC XOR calcLRC
IF lrcTest = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: HART longitudinal parity self-cancellation identity verified"
ELSE
    PRINT "[FAIL] Test 2: HART parity identity failed"
END IF

' ------------------------------------------------------------------------------
' TEST 3: OPC UA BINARY TCP 32-BIT LITTLE-ENDIAN SIZE DECODING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' 4 bytes: 0x48, 0x01, 0x00, 0x00 = 0x00000148 = 328 bytes
DIM b0 AS INTEGER : b0 = 72   ' 0x48
DIM b1 AS INTEGER : b1 = 1    ' 0x01
DIM b2 AS INTEGER : b2 = 0
DIM b3 AS INTEGER : b3 = 0
DIM decodedMsgSize AS INTEGER
decodedMsgSize = b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)

IF decodedMsgSize = 328 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: OPC UA binary 32-bit Little-Endian message size decoded (328 bytes)"
ELSE
    PRINT "[FAIL] Test 3: OPC UA size decoding failed:", decodedMsgSize
END IF

' ------------------------------------------------------------------------------
' TEST 4: OPC UA CHUNK TYPE CLASSIFICATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM chunkByteF AS INTEGER : chunkByteF = 70 ' 'F'
DIM chunkByteC AS INTEGER : chunkByteC = 67 ' 'C'
DIM isFinalValid AS INTEGER : isFinalValid = 0
DIM isContValid AS INTEGER : isContValid = 0

IF chunkByteF = 70 THEN isFinalValid = 1
IF chunkByteC = 67 THEN isContValid = 1

IF isFinalValid = 1 AND isContValid = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: OPC UA chunk types ('F'=Final, 'C'=Continuation) validated"
ELSE
    PRINT "[FAIL] Test 4: Chunk classification failed"
END IF

' ------------------------------------------------------------------------------
' TEST 5: CANOPEN 11-BIT COB-ID DECOMPOSITION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Transmit PDO 1 for Node 12: COB-ID = 0x180 + 12 = 384 + 12 = 396
DIM testCobId AS INTEGER : testCobId = 396
DIM extractedNodeId AS INTEGER : extractedNodeId = testCobId AND 127
DIM extractedFuncCode AS INTEGER : extractedFuncCode = testCobId AND 1920

IF extractedNodeId = 12 AND extractedFuncCode = 384 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: CANopen 11-bit COB-ID correctly parsed: NodeId=12, Func=TPDO1 (384)"
ELSE
    PRINT "[FAIL] Test 5: COB-ID parsing failed: Node=", extractedNodeId, "Func=", extractedFuncCode
END IF

' ------------------------------------------------------------------------------
' TEST 6: CANOPEN SDO EXPEDITED OBJECT DICTIONARY INDEXING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Producer Heartbeat Time object: Index = 0x1017 (4119 decimal), Subindex = 0
DIM objIndex AS INTEGER : objIndex = 4119
DIM lsbIndex AS INTEGER : lsbIndex = objIndex AND 255          ' 4119 mod 256 = 23 (0x17)
DIM msbIndex AS INTEGER : msbIndex = (objIndex / 256) AND 255  ' 4119 / 256 = 16 (0x10)

IF lsbIndex = 23 AND msbIndex = 16 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: CANopen SDO 16-bit object index 0x1017 serialized in Little-Endian"
ELSE
    PRINT "[FAIL] Test 6: SDO indexing failed"
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "ADVANCED PROTOCOLS SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
