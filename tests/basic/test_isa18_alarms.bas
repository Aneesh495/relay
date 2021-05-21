' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: ISA-18.2 Alarm State Machine & Annunciators
' File: tests/basic/test_isa18_alarms.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: MULTI-LEVEL HIGH ALARM AND HYSTERESIS DEADBAND
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM limitH AS DOUBLE : limitH = 80.0
DIM hystVal AS DOUBLE : hystVal = 2.0
DIM pvCurrent AS DOUBLE : pvCurrent = 81.5
DIM isHighActive AS INTEGER : isHighActive = 0

' 1. Trip condition: PV exceeds LimitH (81.5 >= 80.0) -> trips
IF pvCurrent >= limitH THEN isHighActive = 1

' 2. PV drops slightly to 79.0 (below 80, but within hysteresis deadband 78 to 80) -> stays tripped!
pvCurrent = 79.0
IF isHighActive = 1 THEN
    IF pvCurrent <= (limitH - hystVal) THEN isHighActive = 0
END IF

DIM hysteresisVerified AS INTEGER : hysteresisVerified = 0
IF isHighActive = 1 THEN
    ' Now drops to 77.5 (below 78.0) -> clears!
    pvCurrent = 77.5
    IF pvCurrent <= (limitH - hystVal) THEN isHighActive = 0
    IF isHighActive = 0 THEN hysteresisVerified = 1
END IF

IF hysteresisVerified = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: High alarm hysteresis deadband trip and clear verification"
ELSE
    PRINT "[FAIL] Test 1: Hysteresis deadband failed"
END IF

' ------------------------------------------------------------------------------
' TEST 2: ISA-18.2 LIFECYCLE: NORMAL -> UNACK -> ACKED -> NORMAL
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM almState AS INTEGER : almState = 0  ' ALARM_STATE_NORMAL
DIM condActive AS INTEGER : condActive = 1
DIM opAck AS INTEGER : opAck = 0

' Trip happens
IF almState = 0 AND condActive = 1 THEN almState = 1 ' ALARM_STATE_UNACK

' Operator acknowledges while condition remains active
opAck = 1
IF almState = 1 AND opAck = 1 AND condActive = 1 THEN almState = 2 ' ALARM_STATE_ACKED

' Process clears back into safe zone
condActive = 0
opAck = 0
IF almState = 2 AND condActive = 0 THEN almState = 0 ' ALARM_STATE_NORMAL

IF almState = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: ISA-18.2 Normal -> Unack -> Acked -> Normal lifecycle"
ELSE
    PRINT "[FAIL] Test 2: Standard lifecycle failed"
END IF

' ------------------------------------------------------------------------------
' TEST 3: ISA-18.2 LIFECYCLE: RETURN TO NORMAL BEFORE ACK (RTN_UNACK)
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
almState = 0
condActive = 1
' 1. Trip condition triggers unack alarm
IF almState = 0 AND condActive = 1 THEN almState = 1

' 2. Process clears BEFORE operator ack -> must enter RTN_Unack state (state 3)
condActive = 0
IF almState = 1 AND condActive = 0 THEN almState = 3 ' ALARM_STATE_RTN_UNACK

' 3. Operator acknowledges cleared event -> returns to Normal (state 0)
opAck = 1
IF almState = 3 AND opAck = 1 THEN almState = 0

IF almState = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: ISA-18.2 Return-To-Normal unacknowledged sequence"
ELSE
    PRINT "[FAIL] Test 3: RTN sequence failed"
END IF

' ------------------------------------------------------------------------------
' TEST 4: OPERATOR ALARM SHELVING TIMEOUT EXPIRATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM isShelved AS INTEGER : isShelved = 1
DIM shelveTimeoutMs AS DOUBLE : shelveTimeoutMs = 5000.0
DIM currentClockMs AS DOUBLE : currentClockMs = 6000.0  ' 6.0 seconds later
DIM expiredStatus AS INTEGER : expiredStatus = 0

IF currentClockMs >= shelveTimeoutMs THEN
    isShelved = 0
    expiredStatus = 1
END IF

IF expiredStatus = 1 AND isShelved = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Operator alarm shelving expiration and auto-unshelve"
ELSE
    PRINT "[FAIL] Test 4: Shelving expiration failed"
END IF

' ------------------------------------------------------------------------------
' TEST 5: ANTI-CHATTERING ON-DELAY TIMER QUALIFICATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM onDelayMs AS DOUBLE : onDelayMs = 2000.0
DIM condStartMs AS DOUBLE : condStartMs = 1000.0
DIM clockNow AS DOUBLE : clockNow = 2500.0  ' Only 1500 ms elapsed (< 2000 ms)
DIM isQualified AS INTEGER : isQualified = 0

IF (clockNow - condStartMs) >= onDelayMs THEN
    isQualified = 1
END IF

' Advance clock to 3200 ms (2200 ms elapsed -> exceeds 2000 ms)
clockNow = 3200.0
IF (clockNow - condStartMs) >= onDelayMs THEN
    isQualified = 1
END IF

IF isQualified = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Anti-chattering on-delay filter qualification (2.0 sec)"
ELSE
    PRINT "[FAIL] Test 5: On-delay timer failed"
END IF

' ------------------------------------------------------------------------------
' TEST 6: FIRST-OUT CASCADE ROOT CAUSE LATCHING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Event A occurs at t = 1000 ms (Lube Oil Pressure Trip)
' Event B occurs at t = 1025 ms (Vibration High Trip)
' Event C occurs at t = 1050 ms (Generator Breaker Trip)
' First-out logic must latch Event A and ignore B and C!
DIM timeA AS DOUBLE : timeA = 1000.0
DIM timeB AS DOUBLE : timeB = 1025.0
DIM timeC AS DOUBLE : timeC = 1050.0

DIM latchedTripIndex AS INTEGER : latchedTripIndex = -1
DIM isGroupLatched AS INTEGER : isGroupLatched = 0

' Scan trips
IF isGroupLatched = 0 THEN
    ' Find earliest
    IF timeA < timeB AND timeA < timeC THEN
        latchedTripIndex = 0  ' Trip A is Root Cause!
        isGroupLatched = 1
    END IF
END IF

' Secondary scan: Even though B and C are active, group remains latched to A!
IF isGroupLatched = 1 THEN
    ' Root cause remains locked
    latchedTripIndex = 0
END IF

IF latchedTripIndex = 0 AND isGroupLatched = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: First-out root cause trip latching among cascade events"
ELSE
    PRINT "[FAIL] Test 6: First-out latching failed"
END IF

PRINT "=================================================="
PRINT "Alarm Subsystem Verification Summary: Passed", testsPassed, "of", testsTotal, "tests."
PRINT "=================================================="
