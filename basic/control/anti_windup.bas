' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Integral Anti-Windup & Actuator Feedback Tracking
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/anti_windup.bas
' ==============================================================================
'
' This module implements advanced anti-windup strategies to prevent overshoot
' and sluggish recovery when actuators saturate or valves hit travel stops.
' ==============================================================================

' ------------------------------------------------------------------------------
' SECTION 1: EXTERNAL ACTUATOR POSITION TRACKING ANTI-WINDUP
' ------------------------------------------------------------------------------

' CorrectIntegratorExternalFeedback: Adjusts controller integral state using
' true measured actuator position from smart positioner (4-20mA feedback).
' If the mechanical valve is jammed, frozen, or rate-limited, this prevents
' the software integrator from winding up beyond physical valve capability.
SUB CorrectIntegratorExternalFeedback(pid AS PidControllerState, actualValvePosition AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 OR pid.TrackingTimeConst <= 0.0 THEN EXIT SUB

    ' Actuator tracking difference: Real valve position minus commanded output
    DIM posDifference AS DOUBLE
    posDifference = actualValvePosition - pid.ControlOutput

    ' Apply tracking correction to integral state
    DIM correction AS DOUBLE
    correction = (dtSec / pid.TrackingTimeConst) * posDifference
    pid.IntegratorState = pid.IntegratorState + correction
END SUB

' ------------------------------------------------------------------------------
' SECTION 2: CONDITIONAL INTEGRATOR FREEZE
' ------------------------------------------------------------------------------

' ShouldIntegratorFreeze: Determines whether integral accumulation should be suspended
FUNCTION ShouldIntegratorFreeze(commandOp AS DOUBLE, outMin AS DOUBLE, outMax AS DOUBLE, errorVal AS DOUBLE) AS INTEGER
    ' If valve is at upper limit and error is positive (asking for more output), freeze!
    IF commandOp >= outMax AND errorVal > 0.0 THEN
        RETURN 1
    END IF

    ' If valve is at lower limit and error is negative (asking for less output), freeze!
    IF commandOp <= outMin AND errorVal < 0.0 THEN
        RETURN 1
    END IF

    RETURN 0
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 3: INTEGRATOR PRE-LOADING
' ------------------------------------------------------------------------------

' PreloadIntegratorState: Sets the initial integrator value to achieve a specified
' target initial output OP_target on controller initialization or mode switch.
SUB PreloadIntegratorState(pid AS PidControllerState, targetOutput AS DOUBLE, setpoint AS DOUBLE, pv AS DOUBLE)
    DIM pTerm AS DOUBLE
    pTerm = pid.Kp * (pid.Beta * setpoint - pv)
    pid.IntegratorState = targetOutput - pTerm
    pid.ControlOutput = targetOutput
    pid.ManualOutput = targetOutput
END SUB
