' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Integration Test: Exothermic CSTR Closed-Loop Temperature Regulation
' File: tests/integration/test_closed_loop_cstr.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

PRINT "=============================================================================="
PRINT "INTEGRATION TEST: EXOTHERMIC CSTR CLOSED-LOOP TEMPERATURE CONTROL"
PRINT "=============================================================================="

' Reactor Initial Conditions
DIM ca AS DOUBLE : ca = 0.0882       ' Initial concentration (mol / L)
DIM tempK AS DOUBLE : tempK = 311.26 ' Initial temperature (Kelvin)
DIM tempSP AS DOUBLE : tempSP = 315.0' Target setpoint (Kelvin)
DIM coolantFlow AS DOUBLE : coolantFlow = 100.0 ' L / min

DIM dtMin AS DOUBLE : dtMin = 0.02   ' 1.2 second time step
DIM stepIdx AS INTEGER
DIM maxTempObserved AS DOUBLE : maxTempObserved = tempK

' 150-step closed loop simulation
DIM iAccum AS DOUBLE : iAccum = 0.0
FOR stepIdx = 1 TO 150
    ' Controller: Proportional-Integral feedback
    DIM errVal AS DOUBLE : errVal = tempK - tempSP
    iAccum = iAccum + errVal * dtMin
    coolantFlow = 120.0 + 30.0 * errVal + 15.0 * iAccum
    IF coolantFlow < 10.0 THEN coolantFlow = 10.0
    IF coolantFlow > 300.0 THEN coolantFlow = 300.0
    
    ' Kinetics: Arrhenius reaction rate
    DIM kRate AS DOUBLE
    kRate = 7.2E10 * EXP(-8750.0 / tempK)
    
    ' Mass Balance: dCa/dt = (q/V)*(Caf - Ca) - k*Ca
    DIM dCa AS DOUBLE
    dCa = (100.0 / 100.0) * (1.0 - ca) - kRate * ca
    ca = ca + dCa * dtMin
    
    ' Energy Balance: dT/dt = (q/V)*(Tf - T) + reactionHeat - jacketHeat
    DIM reactionHeat AS DOUBLE : reactionHeat = (5.0E4 / 1000.0) * kRate * ca
    DIM jacketHeat AS DOUBLE : jacketHeat = (coolantFlow / 100.0) * (tempK - 292.0) * 1.5
    DIM dTemp AS DOUBLE
    dTemp = (1.0) * (350.0 - tempK) + reactionHeat - jacketHeat
    tempK = tempK + dTemp * dtMin
    
    IF tempK > maxTempObserved THEN maxTempObserved = tempK
NEXT stepIdx

' ------------------------------------------------------------------------------
' VERIFICATION 1: THERMAL RUNAWAY PREVENTED
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
IF maxTempObserved < 360.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Verification 1: Thermal runaway prevented; peak temp:", maxTempObserved, "K (< 360K)"
ELSE
    PRINT "[FAIL] Verification 1: Reactor overheated above runaway threshold:", maxTempObserved
END IF

' ------------------------------------------------------------------------------
' VERIFICATION 2: CLOSED-LOOP CONVERGENCE TO SETPOINT
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
DIM steadyStateError AS DOUBLE : steadyStateError = ABS(tempK - tempSP)
IF steadyStateError < 4.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Verification 2: Closed-loop converged within tolerance:", tempK, "K (Target: 315K)"
ELSE
    PRINT "[FAIL] Verification 2: Convergence failed, final error:", steadyStateError
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "CSTR INTEGRATION RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
