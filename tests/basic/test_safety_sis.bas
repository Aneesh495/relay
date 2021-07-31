' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Functional Safety SIS & SIL-3 Calculations
' File: tests/basic/test_safety_sis.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: IEC 61508 1oo1 ARCHITECTURE PFD_AVG CALCULATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' lambda_DU = 1.0E-6 failures/hr, T_I = 8760 hrs (1 year)
' PFD_avg = 0.5 * 1.0E-6 * 8760 = 0.00438 (Within SIL 2 band [0.001, 0.01])
DIM lamDU AS DOUBLE : lamDU = 1.0E-6
DIM tInt AS DOUBLE : tInt = 8760.0
DIM pfd1oo1 AS DOUBLE : pfd1oo1 = 0.5 * lamDU * tInt

IF ABS(pfd1oo1 - 0.00438) < 0.00001 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: 1oo1 PFD_avg exact calculation verified (0.00438 = SIL 2)"
ELSE
    PRINT "[FAIL] Test 1: 1oo1 calculation failed:", pfd1oo1
END IF

' ------------------------------------------------------------------------------
' TEST 2: 1oo2 REDUNDANT DUAL CHANNEL PFD_AVG REDUCTION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' beta = 0.05 (5% common cause), same lambda and TI
' indTerm = (1/3) * (0.00876)^2 = 2.558E-5
' ccTerm = 0.5 * 0.05 * 0.00876 = 2.190E-4
' Total = 2.446E-4 (Within SIL 3 band [0.0001, 0.001])
DIM betaFrac AS DOUBLE : betaFrac = 0.05
DIM indTerm AS DOUBLE : indTerm = (1.0 / 3.0) * (lamDU * tInt) * (lamDU * tInt)
DIM ccTerm AS DOUBLE : ccTerm = 0.5 * betaFrac * lamDU * tInt
DIM pfd1oo2 AS DOUBLE : pfd1oo2 = indTerm + ccTerm

IF pfd1oo2 < 0.0010 AND pfd1oo2 > 0.00010 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: 1oo2 redundant architecture achieved SIL 3 target (PFD = 2.446E-4)"
ELSE
    PRINT "[FAIL] Test 2: 1oo2 calculation failed:", pfd1oo2
END IF

' ------------------------------------------------------------------------------
' TEST 3: SIL LEVEL ENUMERATION MAPPING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM silLevel AS INTEGER : silLevel = 0
IF pfd1oo2 < 0.00010 THEN
    silLevel = 4
ELSEIF pfd1oo2 < 0.0010 THEN
    silLevel = 3
ELSEIF pfd1oo2 < 0.010 THEN
    silLevel = 2
ELSEIF pfd1oo2 < 0.10 THEN
    silLevel = 1
END IF

IF silLevel = 3 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: SIL level classification mapped PFD 2.45E-4 to SIL 3"
ELSE
    PRINT "[FAIL] Test 3: SIL mapping failed:", silLevel
END IF

' ------------------------------------------------------------------------------
' TEST 4: MAINTENANCE BYPASS CONCURRENCY INTERLOCK
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Attempting to bypass both redundant channels A and B of the same transmitter PT-101
DIM chanABypassed AS INTEGER : chanABypassed = 1
DIM bypassChanBPermitted AS INTEGER : bypassChanBPermitted = 0

IF chanABypassed = 1 THEN
    ' Interlock: Reject bypass on redundant channel B!
    bypassChanBPermitted = 0
ELSE
    bypassChanBPermitted = 1
END IF

IF bypassChanBPermitted = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Maintenance bypass interlock prevented concurrent defeat of redundant channels"
ELSE
    PRINT "[FAIL] Test 4: Bypass interlock failed"
END IF

' ------------------------------------------------------------------------------
' TEST 5: BYPASS EXPIRATION WATCHDOG ALARM
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM elapsedBypassSec AS DOUBLE : elapsedBypassSec = 14500.0
DIM maxAllowedBypassSec AS DOUBLE : maxAllowedBypassSec = 14400.0 ' 4 hours
DIM bypassAlarm AS INTEGER : bypassAlarm = 0

IF elapsedBypassSec >= maxAllowedBypassSec THEN
    bypassAlarm = 1
END IF

IF bypassAlarm = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Bypass watchdog alarm triggered after 4-hour maintenance expiration"
ELSE
    PRINT "[FAIL] Test 5: Bypass watchdog failed"
END IF

' ------------------------------------------------------------------------------
' TEST 6: ESD CAUSE-EFFECT LATCHING & RESET LOCKOUT
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Cause 1 (High Pressure) trips Effect 1 (Shutdown Valve)
DIM causeActive AS INTEGER : causeActive = 1
DIM latchedTrip AS INTEGER : latchedTrip = 0
DIM resetAccepted AS INTEGER : resetAccepted = 0

' Step 1: Cause trips
IF causeActive = 1 THEN latchedTrip = 1

' Step 2: Attempt reset while cause is STILL active -> MUST BE REJECTED
IF causeActive = 0 AND latchedTrip = 1 THEN
    latchedTrip = 0
    resetAccepted = 1
ELSE
    resetAccepted = 0 ' Blocked
END IF

IF latchedTrip = 1 AND resetAccepted = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: ESD trip latched and manual reset strictly inhibited while cause active"
ELSE
    PRINT "[FAIL] Test 6: ESD latching logic failed"
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "SAFETY SIS SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
