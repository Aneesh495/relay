' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Real-Time PID Control Algorithm & Bumpless Transfer Kernel
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/pid_core.bas
' ==============================================================================
'
' This module implements the international standard ISA PID control algorithms:
'   1. ISA Standard / Ideal Form:
'      u(t) = Kp * [ e(t) + (1/Ti) * Integral(e) + Td * (de/dt) ]
'   2. Proportional-on-Measurement (Beta setpoint weighting) to eliminate setpoint kick
'   3. Derivative-on-Measurement (Gamma = 0) with 1st-order low-pass noise filter
'   4. Bumpless Manual-to-Auto and Auto-to-Manual transfer tracking
' ==============================================================================

' ------------------------------------------------------------------------------
' SECTION 1: POSITIONAL ISA PID ALGORITHM
' ------------------------------------------------------------------------------

' ExecutePidCycle: Computes one discrete execution step of the ISA Standard PID
' Inputs:
'   pid: Controller state and tuning records
'   sp: Setpoint in engineering units
'   pv: Current measured process variable in engineering units
'   manualOp: Operator manual output command (0.0 to 100.0%)
'   dtSec: Elapsed loop sample time (seconds)
SUB ExecutePidCycle(pid AS PidControllerState, sp AS DOUBLE, pv AS DOUBLE, manualOp AS DOUBLE, dtSec AS DOUBLE)
    pid.Setpoint = sp
    pid.ProcessVariable = pv
    pid.SampleTimeSec = dtSec

    ' --------------------------------------------------------------------------
    ' MANUAL MODE EXECUTION (BUMPLESS TRACKING)
    ' --------------------------------------------------------------------------
    IF pid.Mode = CTRL_MODE_MANUAL THEN
        pid.ControlOutput = ClampValue(manualOp, pid.OutMin, pid.OutMax)
        pid.ManualOutput = pid.ControlOutput

        ' Back-calculate integrator state to match manual output for bumpless transfer:
        ' In auto mode: OP = P + I + D
        ' At transfer: OP_manual = Kp * (Beta*SP - PV) + I_target - D
        ' Therefore: I_target = OP_manual - Kp * (Beta*SP - PV)
        DIM pTermManual AS DOUBLE
        pTermManual = pid.Kp * (pid.Beta * sp - pv)
        pid.IntegratorState = pid.ControlOutput - pTermManual

        pid.PrevProcessVar = pv
        pid.PrevDerivative = 0.0
        pid.PrevError = sp - pv
        EXIT SUB
    END IF

    ' --------------------------------------------------------------------------
    ' AUTOMATIC CLOSED-LOOP PID CALCULATION
    ' --------------------------------------------------------------------------
    DIM errCurrent AS DOUBLE : errCurrent = sp - pv

    ' 1. Proportional Term (with Setpoint Weighting Beta)
    ' Setpoint weighting Beta: 1.0 = Proportional on error; 0.0 = Proportional on PV
    DIM pTerm AS DOUBLE
    pTerm = pid.Kp * (pid.Beta * sp - pv)

    ' 2. Derivative Term (with First-Order Low-Pass Filter)
    ' Derivative on PV to prevent derivative kick on step setpoint changes:
    ' D_filtered(k) = (Td / (Td + Alpha * dt)) * D_prev - (Kp * Td / (Td + Alpha * dt)) * (PV_curr - PV_prev)
    DIM dTerm AS DOUBLE : dTerm = 0.0
    IF pid.Td > 0.0 AND dtSec > 0.0 THEN
        DIM filterDenom AS DOUBLE
        filterDenom = pid.Td + pid.Alpha * dtSec
        DIM filterA AS DOUBLE : filterA = pid.Td / filterDenom
        DIM filterB AS DOUBLE : filterB = (pid.Kp * pid.Td) / filterDenom

        DIM deltaPv AS DOUBLE : deltaPv = pv - pid.PrevProcessVar
        dTerm = filterA * pid.PrevDerivative - filterB * (deltaPv / dtSec)
        pid.PrevDerivative = dTerm
    ELSE
        pid.PrevDerivative = 0.0
    END IF

    ' 3. Integral Term (with Anti-Windup Clamping or Back-Calculation)
    DIM iTermCandidate AS DOUBLE
    IF pid.Ti > 0.0 AND dtSec > 0.0 THEN
        ' Trapezoidal integration of error: (e_curr + e_prev) * 0.5
        DIM avgErr AS DOUBLE : avgErr = (errCurrent + pid.PrevError) * 0.5
        DIM iDelta AS DOUBLE : iDelta = (pid.Kp / pid.Ti) * avgErr * dtSec
        iTermCandidate = pid.IntegratorState + iDelta
    ELSE
        iTermCandidate = pid.IntegratorState
    END IF

    ' 4. Unsaturated Controller Output
    DIM unsatOutput AS DOUBLE
    unsatOutput = pTerm + iTermCandidate + dTerm

    ' 5. Saturation Limiting (Actuator Constraints 0-100%)
    DIM satOutput AS DOUBLE
    satOutput = ClampValue(unsatOutput, pid.OutMin, pid.OutMax)

    ' 6. Anti-Windup Integrator Correction
    IF pid.AntiWindupMode = 0 THEN
        ' Hard clamp mode: only integrate if output is within actuator limits
        IF unsatOutput = satOutput THEN
            pid.IntegratorState = iTermCandidate
        END IF
    ELSEIF pid.AntiWindupMode = 1 THEN
        ' Back-calculation anti-windup: adjust integrator by tracking difference
        ' Integrator_delta = (Kp/Ti)*e*dt + (dt / Tt) * (satOutput - unsatOutput)
        DIM windupCorrection AS DOUBLE
        windupCorrection = (dtSec / pid.TrackingTimeConst) * (satOutput - unsatOutput)
        pid.IntegratorState = iTermCandidate + windupCorrection
    ELSE
        ' Freeze mode during saturation
        IF (unsatOutput > pid.OutMax AND errCurrent > 0.0) OR (unsatOutput < pid.OutMin AND errCurrent < 0.0) THEN
            ' Freeze integrator (do not accumulate)
        ELSE
            pid.IntegratorState = iTermCandidate
        END IF
    END IF

    ' Update controller outputs and memory
    pid.ControlOutput = satOutput
    pid.ManualOutput = satOutput
    pid.PrevProcessVar = pv
    pid.PrevError = errCurrent
END SUB

' ------------------------------------------------------------------------------
' SECTION 2: VELOCITY FORM PID ALGORITHM
' ------------------------------------------------------------------------------

' ExecuteVelocityPidStep: Computes incremental output change Delta OP:
' Delta OP = Kp * [ (e_k - e_{k-1}) + (dt / Ti) * e_k + (Td / dt) * (e_k - 2*e_{k-1} + e_{k-2}) ]
' OP_k = OP_{k-1} + Delta OP
FUNCTION ExecuteVelocityPidStep(kp AS DOUBLE, ti AS DOUBLE, td AS DOUBLE, dt AS DOUBLE, _
                                e0 AS DOUBLE, e1 AS DOUBLE, e2 AS DOUBLE) AS DOUBLE
    IF dt <= 0.0 THEN RETURN 0.0

    DIM deltaP AS DOUBLE : deltaP = kp * (e0 - e1)
    DIM deltaI AS DOUBLE : deltaI = 0.0
    IF ti > 0.0 THEN
        deltaI = (kp * dt / ti) * e0
    END IF
    DIM deltaD AS DOUBLE : deltaD = 0.0
    IF td > 0.0 THEN
        deltaD = (kp * td / dt) * (e0 - 2.0 * e1 + e2)
    END IF

    RETURN deltaP + deltaI + deltaD
END FUNCTION
