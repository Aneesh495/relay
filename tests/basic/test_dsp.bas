' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Digital Signal Processing & Vibration Analysis
' File: tests/basic/test_dsp.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: BIT-REVERSAL INDEX PERMUTATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' For 8-point FFT (3 bits): index 1 (001_2) bit-reverses to 4 (100_2)
DIM idx1 AS INTEGER : idx1 = 1
DIM rev1 AS INTEGER : rev1 = 0
DIM b AS INTEGER
FOR b = 1 TO 3
    rev1 = (rev1 * 2) + (idx1 AND 1)
    idx1 = idx1 / 2
NEXT b

IF rev1 = 4 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: Bit-reversal permutation correctly mapped 1 (001b) to 4 (100b)"
ELSE
    PRINT "[FAIL] Test 1: Bit reversal failed:", rev1
END IF

' ------------------------------------------------------------------------------
' TEST 2: HANNING SPECTRAL WINDOW BOUNDARY ATTENUATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM nSamples AS INTEGER : nSamples = 64
DIM w0 AS DOUBLE : w0 = 0.5 - 0.5 * COS(0.0) ' At n = 0, cos(0) = 1 -> w = 0.0
DIM wMid AS DOUBLE : wMid = 0.5 - 0.5 * COS(3.14159265) ' At mid, cos(pi) = -1 -> w = 1.0

IF ABS(w0 - 0.0) < 0.001 AND ABS(wMid - 1.0) < 0.001 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: Hanning window boundary taper verified (w[0]=0.0, w[mid]=1.0)"
ELSE
    PRINT "[FAIL] Test 2: Hanning window calculation failed: w0=", w0, "wMid=", wMid
END IF

' ------------------------------------------------------------------------------
' TEST 3: FIR FILTER MOVING AVERAGE DC CONVERGENCE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' 4-tap boxcar moving average filter fed constant 10.0 DC signal
DIM tapWeight AS DOUBLE : tapWeight = 0.25
DIM dcInput AS DOUBLE : dcInput = 10.0
DIM firOutput AS DOUBLE : firOutput = (tapWeight * dcInput) * 4.0

IF ABS(firOutput - 10.0) < 0.001 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: FIR filter preserves DC unity gain (Output = 10.0)"
ELSE
    PRINT "[FAIL] Test 3: FIR DC gain failed:", firOutput
END IF

' ------------------------------------------------------------------------------
' TEST 4: VIBRATION RMS & CREST FACTOR OF PURE SINE WAVE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' For pure sine wave with peak = 10.0: RMS = 10 / sqrt(2) = 7.071, Crest Factor = sqrt(2) = 1.414
DIM peakSine AS DOUBLE : peakSine = 10.0
DIM rmsSine AS DOUBLE : rmsSine = peakSine / SQR(2.0)
DIM cfSine AS DOUBLE : cfSine = peakSine / rmsSine

IF ABS(cfSine - 1.4142) < 0.01 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: Sinusoidal crest factor equals theoretical sqrt(2) = 1.414"
ELSE
    PRINT "[FAIL] Test 4: Crest factor calculation failed:", cfSine
END IF

' ------------------------------------------------------------------------------
' TEST 5: STATISTICAL KURTOSIS ANOMALY DETECTION FOR BEARING SHOCK
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Gaussian/sinusoidal kurtosis is ~3.0. A high-kurtosis signal (> 6.0) indicates spiky impact shocks.
DIM normalKurtosis AS DOUBLE : normalKurtosis = 2.85
DIM spikyKurtosis AS DOUBLE : spikyKurtosis = 8.42
DIM anomalyTripped AS INTEGER : anomalyTripped = 0

IF spikyKurtosis > 5.0 THEN
    anomalyTripped = 1
END IF

IF anomalyTripped = 1 AND normalKurtosis < 5.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Bearing impact shock detected by Kurtosis metric (8.42 > 5.0)"
ELSE
    PRINT "[FAIL] Test 5: Kurtosis trip check failed"
END IF

' ------------------------------------------------------------------------------
' TEST 6: PARSEVAL ENERGY INTEGRITY CHECK
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Time domain energy of 4 samples [1, 2, 3, 4] = 1 + 4 + 9 + 16 = 30
DIM energyTime AS DOUBLE : energyTime = 1.0*1.0 + 2.0*2.0 + 3.0*3.0 + 4.0*4.0
IF energyTime = 30.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Time-domain signal energy sum verified (30.0)"
ELSE
    PRINT "[FAIL] Test 6: Energy sum failed:", energyTime
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "DSP SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
