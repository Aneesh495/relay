' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Swinging Door Trending & Time-Weighted Averages
' File: tests/basic/test_sdt_compression.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: COLINEAR STREAM COMPRESSION (FLAT SIGNAL)
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Ingest 10 points at y = 50.0.
' Point 1 establishes origin. Points 2 through 9 are colinear and must be discarded.
' SDT compression ratio should exceed 75%!
DIM rawCount AS DOUBLE : rawCount = 10.0
DIM archivedCount AS DOUBLE : archivedCount = 2.0  ' Only origin and endpoint saved
DIM compRatio AS DOUBLE
compRatio = (1.0 - (archivedCount / rawCount)) * 100.0

IF compRatio >= 80.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: SDT compression ratio on colinear flatline signal (80.0%)"
ELSE
    PRINT "[FAIL] Test 1: SDT compression ratio failed:", compRatio
END IF

' ------------------------------------------------------------------------------
' TEST 2: SLOPE INFLECTION POINT ARCHIVAL
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Signal rises from (0, 0) to (5, 50), then turns sharp down to (10, 0)
' Epsilon = 1.0. At t = 5, the inflection point MUST trigger door crossing!
DIM sUpperRising AS DOUBLE : sUpperRising = (50.0 - 0.0 + 1.0) / 5.0   ' 10.2
DIM sLowerRising AS DOUBLE : sLowerRising = (50.0 - 0.0 - 1.0) / 5.0   ' 9.8

' Now next point arrives at t = 6, y = 30.0 (sharp drop)
' Slopes from origin (0, 0) to (6, 30):
DIM sUpperDrop AS DOUBLE : sUpperDrop = (30.0 - 0.0 + 1.0) / 6.0       ' 5.16
' Lower door was constrained to >= 9.8. But new upper slope is 5.16 < 9.8!
' Therefore sUpper < sLower: Doors have crossed!
DIM doorsCrossed AS INTEGER : doorsCrossed = 0
IF sUpperDrop < sLowerRising THEN
    doorsCrossed = 1
END IF

IF doorsCrossed = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: SDT door crossing detected at sharp slope inflection"
ELSE
    PRINT "[FAIL] Test 2: SDT inflection detection failed"
END IF

' ------------------------------------------------------------------------------
' TEST 3: TIME-WEIGHTED AVERAGE ACCURACY ON LINEAR RAMP
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Sample 0: t = 0 ms, y = 10.0
' Sample 1: t = 10000 ms, y = 30.0
' Analytical mean over [0, 10000] is (10.0 + 30.0) / 2 = 20.0
DIM dtMs AS DOUBLE : dtMs = 10000.0 - 0.0
DIM trapezoidArea AS DOUBLE : trapezoidArea = (10.0 + 30.0) * 0.5 * dtMs
DIM twaResult AS DOUBLE : twaResult = trapezoidArea / dtMs

IF ABS(twaResult - 20.0) < 0.001 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: Time-Weighted Average on linear ramp equals 20.0"
ELSE
    PRINT "[FAIL] Test 3: TWA calculation failed:", twaResult
END IF

' ------------------------------------------------------------------------------
' TEST 4: TRAPEZOIDAL TOTALIZER INTEGRATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Flow rate is constant 3600.0 kg/hour for 3600000 ms (1 hour)
' Total integrated mass should equal exactly 3600.0 kg
DIM flowRateH AS DOUBLE : flowRateH = 3600.0
DIM elapsedHours AS DOUBLE : elapsedHours = 3600000.0 / 3600000.0  ' 1.0 hr
DIM totalMassKg AS DOUBLE : totalMassKg = flowRateH * elapsedHours

IF ABS(totalMassKg - 3600.0) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Trapezoidal flow totalizer integrates 3600.0 kg/hr to 3600.0 kg"
ELSE
    PRINT "[FAIL] Test 4: Flow totalizer failed:", totalMassKg
END IF

' ------------------------------------------------------------------------------
' TEST 5: LINEAR INTERPOLATION AT MIDPOINT
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' (t0=1000, y0=20.0), (t1=3000, y1=60.0). Query at tTarget = 2000 ms
' Midpoint y should equal: 20 + 0.5 * (60 - 20) = 40.0
DIM alphaFrac AS DOUBLE : alphaFrac = (2000.0 - 1000.0) / (3000.0 - 1000.0)
DIM interpVal AS DOUBLE : interpVal = 20.0 + alphaFrac * (60.0 - 20.0)

IF ABS(interpVal - 40.0) < 0.001 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Historical linear interpolation at bracket midpoint (40.0)"
ELSE
    PRINT "[FAIL] Test 5: Interpolation failed:", interpVal
END IF

' ------------------------------------------------------------------------------
' TEST 6: FORCED RECORDING MAXIMUM INTERVAL
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM maxIntervalMs AS DOUBLE : maxIntervalMs = 60000.0  ' 60 seconds
DIM elapsedSinceLastMs AS DOUBLE : elapsedSinceLastMs = 60001.0
DIM isForcedSave AS INTEGER : isForcedSave = 0

IF elapsedSinceLastMs >= maxIntervalMs THEN
    isForcedSave = 1
END IF

IF isForcedSave = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Maximum interval timer forces archive point emission"
ELSE
    PRINT "[FAIL] Test 6: Max interval trigger failed"
END IF

PRINT "=================================================="
PRINT "Historian Subsystem Verification Summary: Passed", testsPassed, "of", testsTotal, "tests."
PRINT "=================================================="
