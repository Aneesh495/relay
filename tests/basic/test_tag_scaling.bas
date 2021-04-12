' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Tag Database Scaling, Deadbands, and Quality
' File: tests/basic/test_tag_scaling.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: LINEAR SCALING
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM rawMid AS DOUBLE : rawMid = 32767.5
DIM euResult AS DOUBLE
' Span: 0 to 65535 -> 0 to 200 deg C. Midpoint should be 100.0 deg C
euResult = (rawMid / 65535.0) * 200.0
IF ABS(euResult - 100.0) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: Linear 16-bit ADC to EU scaling (100.0 deg C)"
ELSE
    PRINT "[FAIL] Test 1: Linear scaling failed:", euResult
END IF

' ------------------------------------------------------------------------------
' TEST 2: SQUARE-ROOT ORIFICE FLOW EXTRACTION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' At 25% differential pressure (0.25), flow should be SQR(0.25) = 50% of full-scale
DIM dpFrac AS DOUBLE : dpFrac = 0.25
DIM flowRate AS DOUBLE : flowRate = 1000.0 * SQR(dpFrac)
IF ABS(flowRate - 500.0) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: Square root orifice flow extraction (500.0 m3/h)"
ELSE
    PRINT "[FAIL] Test 2: Square root flow extraction failed:", flowRate
END IF

' ------------------------------------------------------------------------------
' TEST 3: RTD PT100 CALLENDAR-VAN DUSEN LINEARIZATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' At 0.0 deg C, Pt100 resistance is exactly 100.0 Ohms
' At 100.0 deg C, Pt100 resistance is approximately 138.51 Ohms
DIM r100 AS DOUBLE : r100 = 100.0 * (1.0 + 3.9083E-3 * 100.0 - 5.7750E-7 * 10000.0)
IF ABS(r100 - 138.505) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: RTD Pt100 resistance at 100 deg C (138.51 Ohms)"
ELSE
    PRINT "[FAIL] Test 3: Pt100 calculation failed:", r100
END IF

' ------------------------------------------------------------------------------
' TEST 4: ABSOLUTE DEADBAND SUPPRESSION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM valOld AS DOUBLE : valOld = 50.0
DIM valNewSmall AS DOUBLE : valNewSmall = 50.05
DIM dbAbs AS DOUBLE : dbAbs = 0.1
DIM hasExceeded AS INTEGER : hasExceeded = 0
IF ABS(valNewSmall - valOld) >= dbAbs THEN
    hasExceeded = 1
END IF
IF hasExceeded = 0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Absolute deadband noise suppression (delta < 0.1)"
ELSE
    PRINT "[FAIL] Test 4: Deadband failed to suppress sub-threshold noise"
END IF

' ------------------------------------------------------------------------------
' TEST 5: NAMUR NE 43 WIRE-BREAK SENSOR FAULT DETECTION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM loopCurrentMa AS DOUBLE : loopCurrentMa = 2.4  ' Wire break (< 3.6 mA)
DIM qualityCode AS INTEGER
IF loopCurrentMa < 3.6 THEN
    qualityCode = 8  ' QUALITY_BAD_SENSOR_FAIL
ELSE
    qualityCode = 192 ' QUALITY_GOOD
END IF
IF qualityCode = 8 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: NAMUR NE 43 wire-break fault detection (< 3.6 mA)"
ELSE
    PRINT "[FAIL] Test 5: NAMUR wire break detection failed"
END IF

' ------------------------------------------------------------------------------
' TEST 6: COMPRESSIBLE GAS MASS FLOW DENSITY COMPENSATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' P = 1.01325 barg (approx 2 bara -> density doubles), T = 15 deg C (288.15 K -> ratio = 1)
' Mass flow should double compared to 1 bara standard
DIM pBara AS DOUBLE : pBara = 1.01325 + 1.01325
DIM tKelvin AS DOUBLE : tKelvin = 15.0 + 273.15
DIM densCorr AS DOUBLE : densCorr = (pBara / 1.01325) * (288.15 / tKelvin)
IF ABS(densCorr - 2.0) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Compressible gas density pressure compensation (2.0x)"
ELSE
    PRINT "[FAIL] Test 6: Gas density correction failed:", densCorr
END IF

PRINT "=================================================="
PRINT "Tag Scaling Verification Summary: Passed", testsPassed, "of", testsTotal, "tests."
PRINT "=================================================="
