' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Dynamic Disturbance Rejection & Lead-Lag Feedforward Compensator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/feedforward.bas
' ==============================================================================
'
' This module implements dynamic feedforward compensation using lead-lag transfer
' functions. By measuring measurable disturbances (e.g., boiler steam demand or
' feed stream temperature) before they impact the process, the feedforward
' compensator preemptively adjusts actuator output to cancel deviation.
' ==============================================================================

' LeadLagFilterState: Discrete state memory for lead-lag compensator
TYPE LeadLagFilterState
    GainKff         AS DOUBLE  ' Static feedforward gain Kff = - (Kp_dist / Kp_proc)
    LeadTimeT1      AS DOUBLE  ' Lead time constant T1 (seconds)
    LagTimeT2       AS DOUBLE  ' Lag time constant T2 (seconds)

    PrevDisturbance AS DOUBLE  ' Disturbance measurement at previous cycle d_{k-1}
    PrevOutput      AS DOUBLE  ' Filtered output at previous cycle y_{k-1}
END TYPE

' InitializeLeadLag: Prepares dynamic compensator parameters
SUB InitializeLeadLag(filter AS LeadLagFilterState, kff AS DOUBLE, tLead AS DOUBLE, tLag AS DOUBLE)
    filter.GainKff = kff
    filter.LeadTimeT1 = tLead
    filter.LagTimeT2 = tLag > 0.0 ? tLag : 0.01
    filter.PrevDisturbance = 0.0
    filter.PrevOutput = 0.0
END SUB

' ExecuteLeadLagStep: Computes discrete step using bilinear transform:
' y_k = ((2*T2 - dt)/(2*T2 + dt)) * y_{k-1} + Kff * ((2*T1 + dt)/(2*T2 + dt)) * d_k - Kff * ((2*T1 - dt)/(2*T2 + dt)) * d_{k-1}
FUNCTION ExecuteLeadLagStep(filter AS LeadLagFilterState, disturbanceVal AS DOUBLE, dtSec AS DOUBLE) AS DOUBLE
    IF dtSec <= 0.0 THEN RETURN filter.PrevOutput

    DIM denom AS DOUBLE : denom = 2.0 * filter.LagTimeT2 + dtSec
    DIM a1 AS DOUBLE : a1 = (2.0 * filter.LagTimeT2 - dtSec) / denom
    DIM b0 AS DOUBLE : b0 = filter.GainKff * (2.0 * filter.LeadTimeT1 + dtSec) / denom
    DIM b1 AS DOUBLE : b1 = -filter.GainKff * (2.0 * filter.LeadTimeT1 - dtSec) / denom

    DIM currentOut AS DOUBLE
    currentOut = a1 * filter.PrevOutput + b0 * disturbanceVal + b1 * filter.PrevDisturbance

    filter.PrevDisturbance = disturbanceVal
    filter.PrevOutput = currentOut

    RETURN currentOut
END FUNCTION

' CombinePidAndFeedforward: Sums feedback PID output with feedforward compensation
FUNCTION CombinePidAndFeedforward(pidOutput AS DOUBLE, ffOutput AS DOUBLE, outMin AS DOUBLE, outMax AS DOUBLE) AS DOUBLE
    DIM totalOp AS DOUBLE
    totalOp = pidOutput + ffOutput
    RETURN ClampValue(totalOp, outMin, outMax)
END FUNCTION
