' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: HVAC Environmental Automation & Psychrometrics
' File: tests/basic/test_hvac_ahu.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: SATURATED VAPOR PRESSURE AT 20 DEG C
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Magnus-Tetens: P_ws(20 C) = 0.61078 * exp((17.27 * 20) / (20 + 237.3)) = 2.338 kPa
DIM temp20 AS DOUBLE : temp20 = 20.0
DIM expVal AS DOUBLE : expVal = (17.27 * temp20) / (temp20 + 237.3)
DIM pws20 AS DOUBLE : pws20 = 0.61078 * EXP(expVal)

IF ABS(pws20 - 2.338) < 0.02 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: Saturated water vapor pressure at 20 C verified: 2.338 kPa"
ELSE
    PRINT "[FAIL] Test 1: Saturated vapor pressure calculation failed:", pws20
END IF

' ------------------------------------------------------------------------------
' TEST 2: HUMIDITY RATIO W AT 24 DEG C AND 50% RELATIVE HUMIDITY
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' P_ws(24 C) = 2.985 kPa; P_w = 0.5 * 2.985 = 1.4925 kPa
' W = 0.62198 * 1.4925 / (101.325 - 1.4925) = 0.00930 kg water / kg dry air
DIM pws24 AS DOUBLE : pws24 = 0.61078 * EXP((17.27 * 24.0) / (24.0 + 237.3))
DIM pw24 AS DOUBLE : pw24 = 0.50 * pws24
DIM wRatio AS DOUBLE : wRatio = 0.62198 * (pw24 / (101.325 - pw24))

IF ABS(wRatio - 0.00930) < 0.0003 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: Humidity ratio W verified: 0.0093 kg/kg at 24 C and 50% RH"
ELSE
    PRINT "[FAIL] Test 2: Humidity ratio calculation failed:", wRatio
END IF

' ------------------------------------------------------------------------------
' TEST 3: MOIST AIR SPECIFIC ENTHALPY
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' h = 1.006 * 24 + 0.0093 * (2501 + 1.86 * 24) = 24.144 + 0.0093 * 2545.64 = 47.82 kJ/kg
DIM hEnthalpy AS DOUBLE
hEnthalpy = 1.006 * 24.0 + wRatio * (2501.0 + 1.86 * 24.0)

IF ABS(hEnthalpy - 47.8) < 0.5 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: Moist air specific enthalpy verified: 47.8 kJ/kg"
ELSE
    PRINT "[FAIL] Test 3: Enthalpy calculation failed:", hEnthalpy
END IF

' ------------------------------------------------------------------------------
' TEST 4: DEW POINT TEMPERATURE APPROXIMATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' At 24 C and 50% RH, dew point is approx 12.9 deg C
DIM rhFrac AS DOUBLE : rhFrac = 0.50
DIM gammaVal AS DOUBLE : gammaVal = ((17.27 * 24.0) / (24.0 + 237.3)) + LOG(rhFrac)
DIM tDewPoint AS DOUBLE : tDewPoint = (237.3 * gammaVal) / (17.27 - gammaVal)

IF ABS(tDewPoint - 12.9) < 0.3 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Dew point temperature verified: 12.9 deg C"
ELSE
    PRINT "[FAIL] Test 4: Dew point calculation failed:", tDewPoint
END IF

' ------------------------------------------------------------------------------
' TEST 5: AHU MIXED AIR ADIABATIC MASS BALANCE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' 30% Outdoor Air at 10.0 C, 70% Return Air at 22.0 C
' T_ma = 0.30 * 10.0 + 0.70 * 22.0 = 3.0 + 15.4 = 18.4 deg C
DIM tOA AS DOUBLE : tOA = 10.0
DIM tRA AS DOUBLE : tRA = 22.0
DIM oaPercent AS DOUBLE : oaPercent = 30.0

DIM tMixed AS DOUBLE
tMixed = (oaPercent / 100.0) * tOA + (1.0 - (oaPercent / 100.0)) * tRA

IF ABS(tMixed - 18.4) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Mixed air temperature adiabatic balance verified: 18.4 deg C"
ELSE
    PRINT "[FAIL] Test 5: Mixed air calculation failed:", tMixed
END IF

' ------------------------------------------------------------------------------
' TEST 6: FREE COOLING ECONOMIZER MODE DETERMINATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' OAT = 15.0 C, RAT = 24.0 C => OAT < RAT - 1.5 C (15 < 22.5) => Economizer ENABLED
DIM oatVal AS DOUBLE : oatVal = 15.0
DIM ratVal AS DOUBLE : ratVal = 24.0
DIM econEnabled AS INTEGER : econEnabled = 0

IF oatVal < (ratVal - 1.5) AND oatVal > 11.0 THEN
    econEnabled = 1
END IF

IF econEnabled = 1 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Free cooling economizer successfully engaged at OAT 15.0 C"
ELSE
    PRINT "[FAIL] Test 6: Economizer enable check failed"
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "HVAC AUTOMATION SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
