' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Microgrid Automation & Electrical Power Systems
' File: tests/basic/test_microgrid_power.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: UNDER-FREQUENCY LOAD SHEDDING STAGE 1 TRIP
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM fGrid AS DOUBLE : fGrid = 49.18 ' Below 49.20 Hz threshold
DIM stage1Tripped AS INTEGER : stage1Tripped = 0
DIM shedMW AS DOUBLE : shedMW = 0.0

IF fGrid <= 49.20 THEN
    stage1Tripped = 1
    shedMW = 12.0
END IF

IF stage1Tripped = 1 AND shedMW = 12.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: UFLS Stage 1 triggered at 49.18 Hz; shed 12.0 MW feeder load"
ELSE
    PRINT "[FAIL] Test 1: UFLS trip failed"
END IF

' ------------------------------------------------------------------------------
' TEST 2: FAST ROCOF RATE-OF-CHANGE-OF-FREQUENCY TRIP
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Frequency drops 0.08 Hz in 0.04 sec (40 ms) => df/dt = -2.0 Hz/sec (< -1.5 Hz/s)
DIM deltaF AS DOUBLE : deltaF = -0.08
DIM dtSec AS DOUBLE : dtSec = 0.040
DIM rocofVal AS DOUBLE : rocofVal = deltaF / dtSec
DIM rocofTrip AS INTEGER : rocofTrip = 0

IF rocofVal < -1.5 THEN
    rocofTrip = 1
END IF

IF rocofTrip = 1 AND rocofVal = -2.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: Fast ROCOF protection tripped on catastrophic df/dt = -2.0 Hz/s"
ELSE
    PRINT "[FAIL] Test 2: ROCOF trip failed:", rocofVal
END IF

' ------------------------------------------------------------------------------
' TEST 3: ANSI 25 SYNCHROCHECK PERMISSIVE CLOSE ASSERTION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM vGen AS DOUBLE : vGen = 13.82
DIM vBus AS DOUBLE : vBus = 13.80
DIM fGen AS DOUBLE : fGen = 50.02
DIM fBus AS DOUBLE : fBus = 50.00
DIM angGen AS DOUBLE : angGen = 5.0
DIM angBus AS DOUBLE : angBus = 0.0

DIM vOk AS INTEGER : vOk = 0
DIM fOk AS INTEGER : fOk = 0
DIM aOk AS INTEGER : aOk = 0
DIM closePermissive AS INTEGER : closePermissive = 0

IF ABS(vGen - vBus) <= 0.69 THEN vOk = 1
IF ABS(fGen - fBus) <= 0.10 THEN fOk = 1
IF ABS(angGen - angBus) <= 10.0 THEN aOk = 1

IF vOk = 1 AND fOk = 1 AND aOk = 1 THEN closePermissive = 1

IF closePermissive = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: ANSI 25 synchrocheck permissive asserted when V, f, theta aligned"
ELSE
    PRINT "[FAIL] Test 3: Synchrocheck close failed"
END IF

' ------------------------------------------------------------------------------
' TEST 4: SYNCHROCHECK PERMISSIVE INHIBITED ON LARGE PHASE ANGLE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM angGenBad AS DOUBLE : angGenBad = 25.0 ' 25 degrees difference (> 10 deg max)
DIM aOkBad AS INTEGER : aOkBad = 0
DIM closePermissiveBad AS INTEGER : closePermissiveBad = 0

IF ABS(angGenBad - angBus) <= 10.0 THEN aOkBad = 1
IF vOk = 1 AND fOk = 1 AND aOkBad = 1 THEN closePermissiveBad = 1

IF closePermissiveBad = 0 AND aOkBad = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Synchrocheck correctly inhibited breaker close on 25 deg phase mismatch"
ELSE
    PRINT "[FAIL] Test 4: Phase angle inhibition failed"
END IF

' ------------------------------------------------------------------------------
' TEST 5: BESS COULOMB COUNTING SOC DISCHARGE INTEGRATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Initial SoC = 80.0%, Discharging at 2500 Amps for 360 seconds (6 minutes)
' Capacity = 12500 Ah. Ah discharged = (2500 * 360) / 3600 = 250 Ah
' Delta SoC = (250 / 12500) * 100 = 2.0% => Final SoC = 78.0%
DIM initSoC AS DOUBLE : initSoC = 80.0
DIM dischAmps AS DOUBLE : dischAmps = 2500.0
DIM durSec AS DOUBLE : durSec = 360.0
DIM capAh AS DOUBLE : capAh = 12500.0

DIM socDelta AS DOUBLE : socDelta = (dischAmps * durSec / (capAh * 3600.0)) * 100.0
DIM finalSoC AS DOUBLE : finalSoC = initSoC - socDelta

IF ABS(finalSoC - 78.0) < 0.001 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: BESS Coulomb counting integrated exact 2.0% SoC discharge (Final: 78.0%)"
ELSE
    PRINT "[FAIL] Test 5: Coulomb counting failed:", finalSoC
END IF

' ------------------------------------------------------------------------------
' TEST 6: BESS OVERCHARGE PREVENTION BOUNDARY ENFORCEMENT
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM fullSoC AS DOUBLE : fullSoC = 92.5 ' Exceeds 90% upper threshold
DIM reqChargePowerKW AS DOUBLE : reqChargePowerKW = -2000.0 ' Charging requested
DIM clampedChargePowerKW AS DOUBLE : clampedChargePowerKW = reqChargePowerKW

IF fullSoC >= 90.0 AND reqChargePowerKW < 0.0 THEN
    clampedChargePowerKW = 0.0 ' Inhibit charge
END IF

IF clampedChargePowerKW = 0.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: BESS supervisory controller blocked charge command at 92.5% SoC ceiling"
ELSE
    PRINT "[FAIL] Test 6: Overcharge boundary failed:", clampedChargePowerKW
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "MICROGRID POWER SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
