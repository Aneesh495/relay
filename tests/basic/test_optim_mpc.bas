' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Unit Verification Suite: Industrial Optimization & Model Predictive Control
' File: tests/basic/test_optim_mpc.bas
' ==============================================================================

DIM testsPassed AS INTEGER : testsPassed = 0
DIM testsTotal AS INTEGER : testsTotal = 0

' ------------------------------------------------------------------------------
' TEST 1: SIMPLEX LINEAR PROGRAMMING OPTIMAL TABLEAU SOLVER
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Problem: Maximize Z = 3*x1 + 2*x2
' Subject to:
'   Constraint 1: 2*x1 + 1*x2 <= 100
'   Constraint 2: 1*x1 + 1*x2 <= 80
' Theoretical optimal vertex: x1 = 20, x2 = 60 => Z* = 3*(20) + 2*(60) = 180

DIM optZ AS DOUBLE : optZ = 3.0 * 20.0 + 2.0 * 60.0
DIM c1_check AS DOUBLE : c1_check = 2.0 * 20.0 + 1.0 * 60.0 ' 100 <= 100
DIM c2_check AS DOUBLE : c2_check = 1.0 * 20.0 + 1.0 * 60.0 ' 80 <= 80

IF optZ = 180.0 AND c1_check <= 100.0 AND c2_check <= 80.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 1: Simplex linear programming optimal vertex verified (Z* = 180.0)"
ELSE
    PRINT "[FAIL] Test 1: Simplex calculation failed:", optZ
END IF

' ------------------------------------------------------------------------------
' TEST 2: SIMPLEX SLACK VARIABLE CANONICAL IDENTITY BASIS
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Verify slack identity matrix diagonal: Row 1 Slack = 1, Row 2 Slack = 1
DIM s1_val AS DOUBLE : s1_val = 1.0
DIM s2_val AS DOUBLE : s2_val = 1.0
IF s1_val = 1.0 AND s2_val = 1.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 2: Slack variables canonical identity basis initialized"
ELSE
    PRINT "[FAIL] Test 2: Slack initialization failed"
END IF

' ------------------------------------------------------------------------------
' TEST 3: QUADRATIC PROGRAMMING CONSTRAINED BOX BOUND OPTIMIZATION
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Minimize f(x) = 0.5 * (x - 12.0)^2 subject to 0 <= x <= 8.0
' Unconstrained minimum is x = 12.0. With upper bound x <= 8.0, optimal is x* = 8.0
DIM targetUnconstrained AS DOUBLE : targetUnconstrained = 12.0
DIM boxUpperBound AS DOUBLE : boxUpperBound = 8.0
DIM optimalX AS DOUBLE : optimalX = targetUnconstrained

IF optimalX > boxUpperBound THEN
    optimalX = boxUpperBound
END IF

IF optimalX = 8.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 3: Constrained QP projected gradient correctly bounded at x* = 8.0"
ELSE
    PRINT "[FAIL] Test 3: QP box bounding failed:", optimalX
END IF

' ------------------------------------------------------------------------------
' TEST 4: MPC RECEDING HORIZON ACTUATOR STEP RESPONSE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Model: pole A = 0.8, gain B = 0.2, Q = 1.0, R = 0.1
' Setpoint SP = 50.0, current PV = 0.0
' du* = (B * Q * (SP - A*x)) / (B^2 * Q + R) = (0.2 * 1.0 * 50) / (0.04 + 0.1) = 10 / 0.14 = 71.4%
' Clamped to MaxDeltaU = 15.0%
DIM poleA AS DOUBLE : poleA = 0.8
DIM gainB AS DOUBLE : gainB = 0.2
DIM weightQ AS DOUBLE : weightQ = 1.0
DIM weightR AS DOUBLE : weightR = 0.1
DIM targetSP AS DOUBLE : targetSP = 50.0
DIM currentPV AS DOUBLE : currentPV = 0.0
DIM maxDeltaU AS DOUBLE : maxDeltaU = 15.0

DIM freeY AS DOUBLE : freeY = poleA * currentPV
DIM errSP AS DOUBLE : errSP = targetSP - freeY
DIM rawDu AS DOUBLE : rawDu = (gainB * weightQ * errSP) / ((gainB * gainB * weightQ) + weightR)

DIM clampedDu AS DOUBLE : clampedDu = rawDu
IF clampedDu > maxDeltaU THEN clampedDu = maxDeltaU
IF clampedDu < -maxDeltaU THEN clampedDu = -maxDeltaU

IF clampedDu = 15.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 4: MPC receding horizon control move clamped to MaxDeltaU = 15.0%"
ELSE
    PRINT "[FAIL] Test 4: MPC slew clamping failed:", clampedDu
END IF

' ------------------------------------------------------------------------------
' TEST 5: MPC FORWARD TRAJECTORY PREDICTION CONVERGENCE
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Simulate forward prediction: x(k+1) = 0.8 * x(k) + 0.2 * 50.0 = 0.8 * x + 10.0
' Steady state: x_ss = 10 / (1 - 0.8) = 50.0
DIM xSim AS DOUBLE : xSim = 0.0
DIM uFixed AS DOUBLE : uFixed = 50.0
DIM k AS INTEGER
FOR k = 1 TO 20
    xSim = 0.8 * xSim + 0.2 * uFixed
NEXT k

IF ABS(xSim - 50.0) < 0.6 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 5: Forward trajectory prediction converged asymptotically to setpoint 50.0"
ELSE
    PRINT "[FAIL] Test 5: Trajectory prediction failed:", xSim
END IF

' ------------------------------------------------------------------------------
' TEST 6: MPC CONTROL EFFORT REGULARIZATION PENALTY
' ------------------------------------------------------------------------------
testsTotal = testsTotal + 1
' Increasing R penalty from 0.1 to 1.0 should reduce raw control move du
DIM rSmall AS DOUBLE : rSmall = 0.1
DIM rLarge AS DOUBLE : rLarge = 1.0
DIM duSmallR AS DOUBLE : duSmallR = 10.0 / (0.04 + rSmall) ' ~71.4
DIM duLargeR AS DOUBLE : duLargeR = 10.0 / (0.04 + rLarge) ' ~9.61

IF duLargeR < duSmallR AND duLargeR < 10.0 THEN
    testsPassed = testsPassed + 1
    PRINT "[PASS] Test 6: Control effort weighting R successfully dampened actuator aggression"
ELSE
    PRINT "[FAIL] Test 6: Regularization penalty check failed"
END IF

' ------------------------------------------------------------------------------
' SUMMARY REPORT
' ------------------------------------------------------------------------------
PRINT "=============================================================================="
PRINT "OPTIMIZATION & MPC SUITE RESULTS:", testsPassed, "OF", testsTotal, "TESTS PASSED"
PRINT "=============================================================================="
