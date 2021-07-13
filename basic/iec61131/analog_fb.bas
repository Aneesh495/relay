' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' IEC 61131-3 Standard Industrial Function Blocks: Analog Signal Blocks
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/iec61131/analog_fb.bas
' ==============================================================================
'
' This module implements the standard IEC 61131-3 analog signal processing blocks:
'   - HYSTERESIS: Schmitt-trigger binary switching with upper and lower thresholds
'   - DERIVATIVE: First-order discrete differentiator with filter lag
'   - INTEGRAL:   Trapezoidal integrator with anti-windup saturation limits
'   - AVERAGE:    Exponential moving average smoothing filter
' ==============================================================================

TYPE HysteresisBlock
    IN              AS DOUBLE  ' Analog input signal
    HIGH_LIMIT      AS DOUBLE  ' Upper trip threshold
    LOW_LIMIT       AS DOUBLE  ' Lower release threshold
    Q               AS INTEGER ' Latched binary state
END TYPE

TYPE DerivativeBlock
    IN              AS DOUBLE  ' Analog input
    TM_Sec          AS DOUBLE  ' Time constant / differentiation period
    OUT             AS DOUBLE  ' Filtered rate of change (dIN/dt)
    LastIN          AS DOUBLE
END TYPE

TYPE IntegralBlock
    IN              AS DOUBLE  ' Analog rate input
    R               AS INTEGER ' Reset accumulator flag
    HOLD            AS INTEGER ' Freeze accumulation flag
    OUT_MIN         AS DOUBLE  ' Minimum saturation limit
    OUT_MAX         AS DOUBLE  ' Maximum saturation limit
    OUT             AS DOUBLE  ' Accumulated integral output
    LastIN          AS DOUBLE
END TYPE

TYPE AverageBlock
    IN              AS DOUBLE  ' Analog input
    ALPHA           AS DOUBLE  ' Exponential smoothing weight [0, 1]
    OUT             AS DOUBLE  ' Smoothed average output
END TYPE

' ExecuteHysteresis: Schmitt-trigger comparator logic
SUB ExecuteHysteresis(h AS HysteresisBlock)
    IF h.IN >= h.HIGH_LIMIT THEN
        h.Q = 1
    ELSEIF h.IN <= h.LOW_LIMIT THEN
        h.Q = 0
    END IF
END SUB

' ExecuteDerivative: Computes filtered rate of change
SUB ExecuteDerivative(d AS DerivativeBlock, dtSec AS DOUBLE)
    IF dtSec <= 0.0001 THEN EXIT SUB
    
    DIM rawDeriv AS DOUBLE : rawDeriv = (d.IN - d.LastIN) / dtSec
    ' Filter derivative with time constant TM_Sec
    IF d.TM_Sec > 0.001 THEN
        DIM alpha AS DOUBLE : alpha = dtSec / (d.TM_Sec + dtSec)
        d.OUT = d.OUT + alpha * (rawDeriv - d.OUT)
    ELSE
        d.OUT = rawDeriv
    END IF
    d.LastIN = d.IN
END SUB

' ExecuteIntegral: Numerical trapezoidal integration with bounding
SUB ExecuteIntegral(iBlock AS IntegralBlock, dtSec AS DOUBLE)
    IF iBlock.R = 1 THEN
        iBlock.OUT = 0.0
        iBlock.LastIN = iBlock.IN
        EXIT SUB
    END IF
    
    IF iBlock.HOLD = 0 AND dtSec > 0.0 THEN
        ' Trapezoidal integration step
        DIM deltaArea AS DOUBLE : deltaArea = (iBlock.IN + iBlock.LastIN) * 0.5 * dtSec
        iBlock.OUT = iBlock.OUT + deltaArea
        
        ' Clamp output to defined limits
        IF iBlock.OUT > iBlock.OUT_MAX THEN iBlock.OUT = iBlock.OUT_MAX
        IF iBlock.OUT < iBlock.OUT_MIN THEN iBlock.OUT = iBlock.OUT_MIN
    END IF
    
    iBlock.LastIN = iBlock.IN
END SUB

' ExecuteAverage: Single-pole exponential moving average
SUB ExecuteAverage(avg AS AverageBlock)
    DIM a AS DOUBLE : a = avg.ALPHA
    IF a < 0.0 THEN a = 0.0
    IF a > 1.0 THEN a = 1.0
    avg.OUT = (1.0 - a) * avg.OUT + a * avg.IN
END SUB
