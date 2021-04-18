' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Signal Filtering & Setpoint Velocity Ramp Profiling
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/filtering.bas
' ==============================================================================
'
' This module implements signal conditioning for control loops:
'   1. 1st-Order Low-Pass Alpha Filter
'   2. 2nd-Order Digital Butterworth Low-Pass Filter
'   3. Linear & S-Curve Setpoint Ramp Profile Generators
' ==============================================================================

' ------------------------------------------------------------------------------
' SECTION 1: FIRST-ORDER LOW-PASS FILTER
' ------------------------------------------------------------------------------

' LowPassFilterAlpha: Discrete exponential smoothing y_k = y_{k-1} + alpha * (x_k - y_{k-1})
' alpha = dt / (RC + dt) where RC is the filter time constant in seconds
FUNCTION LowPassFilterAlpha(prevFiltered AS DOUBLE, currentRaw AS DOUBLE, alpha AS DOUBLE) AS DOUBLE
    alpha = ClampValue(alpha, 0.0, 1.0)
    RETURN prevFiltered + alpha * (currentRaw - prevFiltered)
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 2: 2ND-ORDER BUTTERWORTH LOW-PASS FILTER
' ------------------------------------------------------------------------------

' Butterworth2State: State memory for 2nd-order discrete IIR filter
TYPE Butterworth2State
    X1 AS DOUBLE : X2 AS DOUBLE  ' Past raw inputs
    Y1 AS DOUBLE : Y2 AS DOUBLE  ' Past filtered outputs
END TYPE

' ExecuteButterworth2: Implements 2-pole Butterworth low-pass filter:
' y_k = b0*x_k + b1*x_{k-1} + b2*x_{k-2} - a1*y_{k-1} - a2*y_{k-2}
FUNCTION ExecuteButterworth2(state AS Butterworth2State, x0 AS DOUBLE, _
                             b0 AS DOUBLE, b1 AS DOUBLE, b2 AS DOUBLE, _
                             a1 AS DOUBLE, a2 AS DOUBLE) AS DOUBLE
    DIM y0 AS DOUBLE
    y0 = b0 * x0 + b1 * state.X1 + b2 * state.X2 - a1 * state.Y1 - a2 * state.Y2

    state.X2 = state.X1
    state.X1 = x0
    state.Y2 = state.Y1
    state.Y1 = y0

    RETURN y0
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 3: SETPOINT RAMP GENERATOR
' ------------------------------------------------------------------------------

' SetpointRampState: State tracker for smooth setpoint ramping
TYPE SetpointRampState
    CurrentTargetSp AS DOUBLE  ' Target engineering unit destination
    EffectiveRampSp AS DOUBLE  ' Intermediate ramped value fed to PID loop
    RampRatePerSec  AS DOUBLE  ' Maximum allowed setpoint slew rate (EU/sec)
    IsRamping       AS INTEGER ' 1 if actively ramping, 0 if setpoint reached
END TYPE

' InitializeSetpointRamp: Configures setpoint ramp generator
SUB InitializeSetpointRamp(ramp AS SetpointRampState, initialSp AS DOUBLE, ratePerSec AS DOUBLE)
    ramp.CurrentTargetSp = initialSp
    ramp.EffectiveRampSp = initialSp
    ramp.RampRatePerSec = ratePerSec > 0.0 ? ratePerSec : 1.0
    ramp.IsRamping = 0
END SUB

' UpdateSetpointRamp: Advances the effective setpoint toward target destination
FUNCTION UpdateSetpointRamp(ramp AS SetpointRampState, newTargetSp AS DOUBLE, dtSec AS DOUBLE) AS DOUBLE
    ramp.CurrentTargetSp = newTargetSp
    IF dtSec <= 0.0 THEN RETURN ramp.EffectiveRampSp

    DIM maxStep AS DOUBLE : maxStep = ramp.RampRatePerSec * dtSec
    DIM delta AS DOUBLE : delta = ramp.CurrentTargetSp - ramp.EffectiveRampSp

    IF ABS(delta) <= maxStep THEN
        ramp.EffectiveRampSp = ramp.CurrentTargetSp
        ramp.IsRamping = 0
    ELSEIF delta > 0.0 THEN
        ramp.EffectiveRampSp = ramp.EffectiveRampSp + maxStep
        ramp.IsRamping = 1
    ELSE
        ramp.EffectiveRampSp = ramp.EffectiveRampSp - maxStep
        ramp.IsRamping = 1
    END IF

    RETURN ramp.EffectiveRampSp
END FUNCTION
