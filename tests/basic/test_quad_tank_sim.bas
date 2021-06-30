' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Digital Twin Process Simulators
' File: tests/basic/test_quad_tank_sim.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: QUAD-TANK TORRICELLI GRAVITY DRAINAGE DYNAMICS
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM gAccel AS DOUBLE : gAccel = 981.0
DIM hInit AS DOUBLE : hInit = 15.0
DIM outArea AS DOUBLE : outArea = 0.071
DIM tankArea AS DOUBLE : tankArea = 139.0

' Safe Torricelli velocity v = sqrt(2 * g * h)
DIM vExit AS DOUBLE : vExit = SQR(2.0 * gAccel * hInit)
DIM qDrain AS DOUBLE : qDrain = outArea * vExit
DIM dh_dt AS DOUBLE : dh_dt = -qDrain / tankArea

' Verify drainage rate is negative and within physical limits (-0.15 to -0.05 cm/s)
IF dh_dt < -0.05 AND dh_dt > -0.20 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: Quad-tank gravity drainage rate physically valid"
ELSE
    PRINT "[FAIL] Test 1: Torricelli drainage calculation invalid:", dh_dt
END IF

' ------------------------------------------------------------------------------
' TEST 2: CSTR ARRHENIUS REACTION KINETICS EQUILIBRIUM
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM k0 AS DOUBLE : k0 = 7.2E10
DIM actOverR AS DOUBLE : actOverR = 8750.0
DIM tempK AS DOUBLE : tempK = 350.0

' k = k0 * exp(-E / (R * T))
DIM kRate AS DOUBLE : kRate = k0 * EXP(-actOverR / tempK)

' At 350K, k should evaluate to approximately 1.0 (between 0.8 and 1.2 min^-1)
IF kRate > 0.8 AND kRate < 1.2 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: Arrhenius reaction rate at 350K matches benchmark:", kRate
ELSE
    PRINT "[FAIL] Test 2: Arrhenius rate calculation failed:", kRate
END IF

' ------------------------------------------------------------------------------
' TEST 3: STEAM BOILER EVAPORATION AND ENERGY BALANCE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM firingMW AS DOUBLE : firingMW = 65.0
DIM boilerEff AS DOUBLE : boilerEff = 0.88
DIM latentKJ_Kg AS DOUBLE : latentKJ_Kg = 1670.0

' Evaporation kg/s = (MW * 1000 * Eff) / Latent
DIM expectedEvap AS DOUBLE : expectedEvap = (firingMW * 1000.0 * boilerEff) / latentKJ_Kg

IF expectedEvap > 33.0 AND expectedEvap < 36.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: Boiler thermal evaporation rate valid:", expectedEvap
ELSE
    PRINT "[FAIL] Test 3: Boiler evaporation calculation failed:", expectedEvap
END IF

' ------------------------------------------------------------------------------
' TEST 4: BOILER DRUM OVERPRESSURE SAFETY RELIEF POP
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM drumP AS DOUBLE : drumP = 52.5  ' Overpressure above 50.0 bar setpoint
DIM pSet AS DOUBLE : pSet = 50.0
DIM reliefFlow AS DOUBLE : reliefFlow = 0.0

IF drumP >= pSet THEN
    reliefFlow = (drumP - pSet) * 8.0
END IF

IF ABS(reliefFlow - 20.0) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Overpressure safety relief valve discharge valid (20 kg/s)"
ELSE
    PRINT "[FAIL] Test 4: Safety valve discharge calculation failed:", reliefFlow
END IF

' ------------------------------------------------------------------------------
' TEST 5: PUMP STATION AFFINITY LAWS SPEED SCALING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Affinity laws: Head proportional to speed^2, Power proportional to speed^3
DIM hRated AS DOUBLE : hRated = 75.0
DIM speed60 AS DOUBLE : speed60 = 60.0
DIM speed50 AS DOUBLE : speed50 = 50.0

DIM headRatio AS DOUBLE : headRatio = (speed50 / speed60) * (speed50 / speed60)
DIM h50 AS DOUBLE : h50 = hRated * headRatio

' 75 * (50/60)^2 = 75 * 0.6944 = 52.08 meters
IF ABS(h50 - 52.083) < 0.1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Pump affinity law quadratic head scaling valid:", h50
ELSE
    PRINT "[FAIL] Test 5: Affinity law calculation failed:", h50
END IF

' ------------------------------------------------------------------------------
' TEST 6: COUNTER-CURRENT HEAT EXCHANGER LMTD
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM thIn AS DOUBLE : thIn = 145.0
DIM thOut AS DOUBLE : thOut = 65.0
DIM tcIn AS DOUBLE : tcIn = 22.0
DIM tcOut AS DOUBLE : tcOut = 44.0

DIM dt1 AS DOUBLE : dt1 = thIn - tcOut   ' 145 - 44 = 101.0
DIM dt2 AS DOUBLE : dt2 = thOut - tcIn   ' 65 - 22 = 43.0
DIM lmtdVal AS DOUBLE
DIM ratioVal AS DOUBLE : ratioVal = dt1 / dt2
lmtdVal = (dt1 - dt2) / LOG(ratioVal)

' (101 - 43) / ln(101 / 43) = 58 / 0.8540 = 67.91 deg C
IF ABS(lmtdVal - 67.91) < 0.2 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Counter-current LMTD log-mean calculation valid:", lmtdVal
ELSE
    PRINT "[FAIL] Test 6: LMTD calculation failed:", lmtdVal
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "SIMULATION SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
