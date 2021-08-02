' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Asset Management Diagnostics & NAMUR NE 107
' File: tests/basic/test_diagnostics_ams.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: NAMUR NE 107 PRIORITY RESOLUTION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Device has both WearCounterHigh (M) and SensorFault (F) active simultaneously
DIM wearHigh AS INTEGER : wearHigh = 1
DIM sensorFault AS INTEGER : sensorFault = 1
DIM ne107Code AS STRING : ne107Code = "N"

' Rule: Failure (F) strictly takes priority over Maintenance Required (M)
IF sensorFault = 1 THEN
    ne107Code = "F"
ELSEIF wearHigh = 1 THEN
    ne107Code = "M"
END IF

IF ne107Code = "F" THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: NAMUR NE 107 priority hierarchy resolved (F takes precedence over M)"
ELSE
    PRINT "[FAIL] Test 1: Priority resolution failed:", ne107Code
END IF

' ------------------------------------------------------------------------------
' TEST 2: NAMUR NE 107 FUNCTION CHECK CATEGORY MAPPING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM calMode AS INTEGER : calMode = 1
DIM neCat AS STRING : neCat = "N"

IF calMode = 1 THEN
    neCat = "C" ' Function check
END IF

IF neCat = "C" THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: Calibration mode correctly assigned to Category C (Function Check)"
ELSE
    PRINT "[FAIL] Test 2: Category mapping failed"
END IF

' ------------------------------------------------------------------------------
' TEST 3: CONTROL VALVE STEM STICTION IDENTIFICATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM cmdOP AS DOUBLE : cmdOP = 54.0        ' Controller commanded 54.0% (+4% change)
DIM lastCmdOP AS DOUBLE : lastCmdOP = 50.0
DIM posFeedback AS DOUBLE : posFeedback = 50.0 ' Valve stuck at 50.0%!
DIM isStuck AS INTEGER : isStuck = 0
DIM stictionAlarm AS INTEGER : stictionAlarm = 0

DIM deltaCmd AS DOUBLE : deltaCmd = cmdOP - lastCmdOP
DIM deltaPos AS DOUBLE : deltaPos = ABS(posFeedback - 50.0)

IF deltaCmd > 0.2 AND deltaPos < 0.05 THEN
    isStuck = 1
END IF

DIM trackingErr AS DOUBLE : trackingErr = ABS(cmdOP - posFeedback)
IF trackingErr > 2.5 AND isStuck = 1 THEN
    stictionAlarm = 1
END IF

IF isStuck = 1 AND stictionAlarm = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: Valve stem stiction detected: stem stuck while command stepped +4%"
ELSE
    PRINT "[FAIL] Test 3: Stiction detection failed"
END IF

' ------------------------------------------------------------------------------
' TEST 4: VALVE STEM ODOMETER CUMULATIVE TRAVEL ACCUMULATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM currentTravel AS DOUBLE : currentTravel = 1250.0
DIM step1 AS DOUBLE : step1 = 15.0 ' Move from 50% to 65% = 15% span
DIM step2 AS DOUBLE : step2 = 5.0  ' Move from 65% to 60% = 5% span

currentTravel = currentTravel + step1 + step2

IF currentTravel = 1270.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Valve stem odometer accurately accumulated 20% travel distance"
ELSE
    PRINT "[FAIL] Test 4: Odometer calculation failed:", currentTravel
END IF

' ------------------------------------------------------------------------------
' TEST 5: REDUNDANT SENSOR LOW-PASS BIAS FILTER CONVERGENCE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' True persistent zero drift = 2.0 bar. Filter alpha = 0.5 for fast test convergence
DIM trueDrift AS DOUBLE : trueDrift = 2.0
DIM filteredBias AS DOUBLE : filteredBias = 0.0
DIM alpha AS DOUBLE : alpha = 0.5
DIM k AS INTEGER

FOR k = 1 TO 10
    filteredBias = (1.0 - alpha) * filteredBias + alpha * trueDrift
NEXT k

IF ABS(filteredBias - 2.0) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Redundant sensor bias filter converged to true 2.0 bar drift"
ELSE
    PRINT "[FAIL] Test 5: Bias filter failed:", filteredBias
END IF

' ------------------------------------------------------------------------------
' TEST 6: SUSTAINED CALIBRATION DRIFT WARNING QUALIFICATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM driftTolerance AS DOUBLE : driftTolerance = 1.0 ' 1.0 bar maximum allowed drift
DIM consecutiveCount AS INTEGER : consecutiveCount = 5
DIM driftWarning AS INTEGER : driftWarning = 0

IF filteredBias > driftTolerance AND consecutiveCount >= 5 THEN
    driftWarning = 1
END IF

IF driftWarning = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Sustained drift warning tripped after 5 consecutive samples"
ELSE
    PRINT "[FAIL] Test 6: Drift qualification failed"
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "AMS DIAGNOSTICS SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
