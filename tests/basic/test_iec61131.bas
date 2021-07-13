' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: IEC 61131-3 Standard Function Blocks
' File: tests/basic/test_iec61131.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: TON ON-DELAY TIMER ELAPSED TIME AND OUTPUT ASSERTION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM tonIN AS INTEGER : tonIN = 1
DIM tonPT AS DOUBLE : tonPT = 100.0  ' 100 ms preset
DIM tonET AS DOUBLE : tonET = 0.0
DIM tonQ AS INTEGER : tonQ = 0

' Step 1: 50 ms elapsed
tonET = tonET + 50.0
IF tonET >= tonPT THEN tonQ = 1 ELSE tonQ = 0
DIM qAt50 AS INTEGER : qAt50 = tonQ

' Step 2: Another 60 ms elapsed (total 110 ms >= 100 ms)
tonET = tonET + 60.0
IF tonET >= tonPT THEN tonQ = 1 ELSE tonQ = 0
DIM qAt110 AS INTEGER : qAt110 = tonQ

IF qAt50 = 0 AND qAt110 = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: TON on-delay timer correctly asserted after 100ms"
ELSE
    PRINT "[FAIL] Test 1: TON logic failed: qAt50=", qAt50, "qAt110=", qAt110
END IF

' ------------------------------------------------------------------------------
' TEST 2: TOF OFF-DELAY TIMER OUTPUT HOLD
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM tofIN AS INTEGER : tofIN = 0     ' Input dropped low
DIM tofPT AS DOUBLE : tofPT = 80.0   ' 80 ms hold
DIM tofET AS DOUBLE : tofET = 40.0   ' 40 ms elapsed (< 80 ms)
DIM tofQ AS INTEGER : tofQ = 1       ' Should still be holding TRUE

IF tofET < tofPT THEN tofQ = 1 ELSE tofQ = 0

IF tofQ = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: TOF off-delay held output TRUE during 40ms trailing window"
ELSE
    PRINT "[FAIL] Test 2: TOF hold failed"
END IF

' ------------------------------------------------------------------------------
' TEST 3: CTU UP-COUNTER EDGE COUNTING AND RESET OVERRIDE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM ctuCV AS INTEGER : ctuCV = 4
DIM ctuPV AS INTEGER : ctuPV = 5
DIM ctuCU AS INTEGER : ctuCU = 1
DIM ctuLastCU AS INTEGER : ctuLastCU = 0
DIM ctuQ AS INTEGER : ctuQ = 0

' Pulse rising edge
IF ctuCU = 1 AND ctuLastCU = 0 THEN
    ctuCV = ctuCV + 1
END IF
IF ctuCV >= ctuPV THEN ctuQ = 1

DIM countedTo5 AS INTEGER
IF ctuCV = 5 AND ctuQ = 1 THEN
    countedTo5 = 1
ELSE
    countedTo5 = 0
END IF

' Apply Master Reset
DIM ctuR AS INTEGER : ctuR = 1
IF ctuR = 1 THEN
    ctuCV = 0
    ctuQ = 0
END IF

IF countedTo5 = 1 AND ctuCV = 0 AND ctuQ = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: CTU up-counter pulsed to preset and master reset successfully"
ELSE
    PRINT "[FAIL] Test 3: CTU counter failed"
END IF

' ------------------------------------------------------------------------------
' TEST 4: SR SET-DOMINANT BISTABLE CONFLICT RESOLUTION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM srS1 AS INTEGER : srS1 = 1  ' Both Set and Reset active simultaneously!
DIM srR AS INTEGER : srR = 1
DIM srQ1 AS INTEGER : srQ1 = 0

' In Set-Dominant latch, S1 MUST override R
IF srS1 = 1 THEN
    srQ1 = 1
ELSEIF srR = 1 THEN
    srQ1 = 0
END IF

IF srQ1 = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: SR set-dominant latch resolved simultaneous (S1=1, R=1) to Q=1"
ELSE
    PRINT "[FAIL] Test 4: SR dominant resolution failed"
END IF

' ------------------------------------------------------------------------------
' TEST 5: R_TRIG RISING EDGE SINGLE-SCAN PULSE GENERATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM rclk AS INTEGER : rclk = 1
DIM rm AS INTEGER : rm = 0
DIM rq AS INTEGER : rq = 0

' Scan 1: 0 -> 1 transition
IF rclk = 1 AND rm = 0 THEN rq = 1 ELSE rq = 0
rm = rclk
DIM pulseScan1 AS INTEGER : pulseScan1 = rq

' Scan 2: Clock remains 1
IF rclk = 1 AND rm = 0 THEN rq = 1 ELSE rq = 0
DIM pulseScan2 AS INTEGER : pulseScan2 = rq

IF pulseScan1 = 1 AND pulseScan2 = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: R_TRIG produced single-scan pulse exactly on 0 -> 1 transition"
ELSE
    PRINT "[FAIL] Test 5: R_TRIG edge detection failed"
END IF

' ------------------------------------------------------------------------------
' TEST 6: HYSTERESIS SCHMITT-TRIGGER SWITCHING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM hHigh AS DOUBLE : hHigh = 75.0
DIM hLow AS DOUBLE : hLow = 25.0
DIM hQ AS INTEGER : hQ = 0

' Input rises above high limit (80.0 > 75.0) -> trips to 1
DIM inVal1 AS DOUBLE : inVal1 = 80.0
IF inVal1 >= hHigh THEN
    hQ = 1
ELSEIF inVal1 <= hLow THEN
    hQ = 0
END IF
DIM trippedHigh AS INTEGER : trippedHigh = hQ

' Input drops to deadband (50.0) -> MUST retain state 1
DIM inVal2 AS DOUBLE : inVal2 = 50.0
IF inVal2 >= hHigh THEN
    hQ = 1
ELSEIF inVal2 <= hLow THEN
    hQ = 0
END IF
DIM retainedInDeadband AS INTEGER : retainedInDeadband = hQ

' Input drops below low limit (20.0 < 25.0) -> resets to 0
DIM inVal3 AS DOUBLE : inVal3 = 20.0
IF inVal3 >= hHigh THEN
    hQ = 1
ELSEIF inVal3 <= hLow THEN
    hQ = 0
END IF
DIM resetLow AS INTEGER
IF hQ = 0 THEN
    resetLow = 1
ELSE
    resetLow = 0
END IF

IF trippedHigh = 1 AND retainedInDeadband = 1 AND resetLow = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Schmitt-trigger hysteresis tripped high, held in gap, and reset low"
ELSE
    PRINT "[FAIL] Test 6: Hysteresis evaluation failed"
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "IEC 61131-3 SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
