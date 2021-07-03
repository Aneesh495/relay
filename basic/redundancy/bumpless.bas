' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Bumpless Redundancy Transfer & Actuator Slew Rate Harmonizer
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/redundancy/bumpless.bas
' ==============================================================================
'
' This module guarantees bumpless actuator transfer during controller failover:
'   - Matches newly promoted primary output with actual field valve readback
'   - Backward recalculation of PID integral accumulators to eliminate bump
'   - Dynamic slew-rate limiting during transition grace period
'   - Output deviation alarm when field valve fails to follow setpoint
' ==============================================================================

TYPE BumplessManager
    IsTransitionActive AS INTEGER ' 1 = Transfer window open, 0 = Steady state
    TransitionTimerSec AS DOUBLE  ' Elapsed time in transition mode
    GracePeriodSec     AS DOUBLE  ' Duration of slew limiting (e.g. 3.0 sec)
    MaxSlewRatePctSec  AS DOUBLE  ' Maximum allowed output change rate (% / sec)
    
    LastKnownActuatorOP AS DOUBLE ' Captured valve readback at instant of failover
    FilteredTargetOP    AS DOUBLE ' Slewed control output sent to field
    DeviationLimitPct   AS DOUBLE ' Actuator tracking error trip threshold
    DeviationAlarm      AS INTEGER ' 1 if error > limit
END TYPE

' InitializeBumplessManager: Configures smooth failover parameters
SUB InitializeBumplessManager(mgr AS BumplessManager)
    mgr.IsTransitionActive = 0
    mgr.TransitionTimerSec = 0.0
    mgr.GracePeriodSec = 3.0        ' 3-second transition smoothing window
    mgr.MaxSlewRatePctSec = 10.0    ' Max 10% valve movement per second during transfer
    mgr.LastKnownActuatorOP = 50.0
    mgr.FilteredTargetOP = 50.0
    mgr.DeviationLimitPct = 5.0     ' 5% tracking error tolerance
    mgr.DeviationAlarm = 0
END SUB

' TriggerFailoverTransfer: Called at exact moment standby becomes primary
SUB TriggerFailoverTransfer(mgr AS BumplessManager, fieldReadbackOP AS DOUBLE)
    mgr.IsTransitionActive = 1
    mgr.TransitionTimerSec = 0.0
    mgr.LastKnownActuatorOP = fieldReadbackOP
    mgr.FilteredTargetOP = fieldReadbackOP
    mgr.DeviationAlarm = 0
END SUB

' CalculateBumplessOutput: Harmonizes raw PID calculation with actuator dynamics
FUNCTION CalculateBumplessOutput(mgr AS BumplessManager, rawPidOutput AS DOUBLE, fieldReadbackOP AS DOUBLE, dtSec AS DOUBLE) AS DOUBLE
    IF dtSec <= 0.0 THEN
        CalculateBumplessOutput = mgr.FilteredTargetOP
        EXIT FUNCTION
    END IF
    
    IF mgr.IsTransitionActive = 1 THEN
        mgr.TransitionTimerSec = mgr.TransitionTimerSec + dtSec
        
        ' Rate of change limiter: limit |raw - current| to maxSlew * dt
        DIM desiredDelta AS DOUBLE : desiredDelta = rawPidOutput - mgr.FilteredTargetOP
        DIM maxStep AS DOUBLE : maxStep = mgr.MaxSlewRatePctSec * dtSec
        
        IF desiredDelta > maxStep THEN
            desiredDelta = maxStep
        ELSEIF desiredDelta < -maxStep THEN
            desiredDelta = -maxStep
        END IF
        
        mgr.FilteredTargetOP = mgr.FilteredTargetOP + desiredDelta
        
        ' End transition window when timer expires or error collapses
        IF mgr.TransitionTimerSec >= mgr.GracePeriodSec OR ABS(rawPidOutput - mgr.FilteredTargetOP) < 0.05 THEN
            mgr.IsTransitionActive = 0
        END IF
    ELSE
        ' Normal steady-state operation: pass-through with standard clamping
        mgr.FilteredTargetOP = rawPidOutput
    END IF
    
    ' Clamp output to standard 0 to 100% actuator range
    mgr.FilteredTargetOP = ClampValue(mgr.FilteredTargetOP, 0.0, 100.0)
    
    ' Field tracking deviation supervision
    DIM trackingError AS DOUBLE : trackingError = ABS(mgr.FilteredTargetOP - fieldReadbackOP)
    IF trackingError > mgr.DeviationLimitPct THEN
        mgr.DeviationAlarm = 1
    ELSE
        mgr.DeviationAlarm = 0
    END IF
    
    CalculateBumplessOutput = mgr.FilteredTargetOP
END FUNCTION

' RebiasPidIntegral: Adjusts integral term so PID output exactly equals target
FUNCTION RebiasPidIntegral(targetOutput AS DOUBLE, proportionalTerm AS DOUBLE, feedforwardTerm AS DOUBLE) AS DOUBLE
    ' Output = P + I + FF => I = Output - P - FF
    RebiasPidIntegral = targetOutput - proportionalTerm - feedforwardTerm
END FUNCTION
