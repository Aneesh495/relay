' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Calculated Process Tags & Mass Flow Compensation Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/tags/calculated.bas
' ==============================================================================
'
' This module implements synthetic calculated tags, thermodynamic compensation
' for compressible gas and steam mass flow, thermal heat transfer power calculations,
' and trapezoidal totalizers.
' ==============================================================================

CONST STD_PRESSURE_BARA = 1.01325  ' Standard absolute atmospheric pressure
CONST STD_TEMP_KELVIN   = 288.15   ' Standard base temperature (15 deg C)

' ------------------------------------------------------------------------------
' SECTION 1: COMPRESSIBLE GAS MASS FLOW COMPENSATION
' ------------------------------------------------------------------------------

' CompensateGasMassFlow: Calculates standardized mass flow rate (kg/h) from
' measured uncompensated volumetric flow rate (m3/h), static pressure (bar gauge),
' and process temperature (deg C) using the ideal gas density correction:
' m_dot = Q_vol * rho_base * (P_abs / P_base) * (T_base / T_abs)
FUNCTION CompensateGasMassFlow(volumetricFlowM3h AS DOUBLE, staticPressureBarg AS DOUBLE, _
                               tempDegC AS DOUBLE, baseDensityKgM3 AS DOUBLE) AS DOUBLE
    DIM pAbsBara AS DOUBLE : pAbsBara = staticPressureBarg + 1.01325
    DIM tAbsKelvin AS DOUBLE : tAbsKelvin = tempDegC + 273.15

    IF tAbsKelvin <= 0.0 OR pAbsBara <= 0.0 THEN
        RETURN 0.0
    END IF

    DIM densityCorrection AS DOUBLE
    densityCorrection = (pAbsBara / STD_PRESSURE_BARA) * (STD_TEMP_KELVIN / tAbsKelvin)

    RETURN volumetricFlowM3h * baseDensityKgM3 * densityCorrection
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 2: THERMAL POWER AND HEAT DUTY
' ------------------------------------------------------------------------------

' CalculateThermalDutyKw: Computes thermal heat transfer rate Q_dot (in kilowatts):
' Q_dot = (m_dot_kgh / 3600) * Cp * (T_out - T_in)
' cpKjKgK is specific heat capacity (e.g. 4.184 kJ/kg.K for water)
FUNCTION CalculateThermalDutyKw(massFlowKgH AS DOUBLE, tempInDegC AS DOUBLE, _
                                tempOutDegC AS DOUBLE, cpKjKgK AS DOUBLE) AS DOUBLE
    DIM deltaT AS DOUBLE : deltaT = tempOutDegC - tempInDegC
    DIM massFlowKgSec AS DOUBLE : massFlowKgSec = massFlowKgH / 3600.0
    RETURN massFlowKgSec * cpKjKgK * deltaT
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 3: CONTINUOUS FLOW TOTALIZATION ACCUMULATOR
' ------------------------------------------------------------------------------

' FlowTotalizerState: Integrator memory for continuous totalizer
TYPE FlowTotalizerState
    AccumulatedTotal AS DOUBLE  ' Total integrated units (e.g., kg or liters)
    LastTimestampMs  AS DOUBLE  ' Previous sample time
    LastFlowRate     AS DOUBLE  ' Previous instantaneous flow rate
    IsActive         AS INTEGER ' 1 if accumulating, 0 if paused
END TYPE

' InitializeFlowTotalizer: Resets accumulator memory
SUB InitializeFlowTotalizer(tot AS FlowTotalizerState)
    tot.AccumulatedTotal = 0.0
    tot.LastTimestampMs = 0.0
    tot.LastFlowRate = 0.0
    tot.IsActive = 1
END SUB

' UpdateFlowTotalizer: Integrates instantaneous flow rate (units per hour)
' over elapsed time delta dt using the trapezoidal rule:
' Integral = (Rate_prev + Rate_curr) * 0.5 * (dt_hours)
SUB UpdateFlowTotalizer(tot AS FlowTotalizerState, currentFlowRatePerHour AS DOUBLE, currentClockMs AS DOUBLE)
    IF tot.IsActive = 0 THEN EXIT SUB

    IF tot.LastTimestampMs <= 0.0 THEN
        tot.LastTimestampMs = currentClockMs
        tot.LastFlowRate = currentFlowRatePerHour
        EXIT SUB
    END IF

    DIM dtMs AS DOUBLE : dtMs = currentClockMs - tot.LastTimestampMs
    IF dtMs <= 0.0 THEN EXIT SUB

    DIM dtHours AS DOUBLE : dtHours = dtMs / 3600000.0
    DIM avgRate AS DOUBLE : avgRate = (tot.LastFlowRate + currentFlowRatePerHour) * 0.5

    tot.AccumulatedTotal = tot.AccumulatedTotal + avgRate * dtHours
    tot.LastTimestampMs = currentClockMs
    tot.LastFlowRate = currentFlowRatePerHour
END SUB

' ------------------------------------------------------------------------------
' SECTION 4: ROLLING MOVING AVERAGE FILTER
' ------------------------------------------------------------------------------

' MovingAverageBuffer: Ring buffer for sliding window rolling average
TYPE MovingAverageBuffer
    WindowSize AS INTEGER
    Samples(64) AS DOUBLE
    HeadIndex AS INTEGER
    Count AS INTEGER
    RunningSum AS DOUBLE
END TYPE

' InitMovingAverage: Prepares moving average filter
SUB InitMovingAverage(buf AS MovingAverageBuffer, size AS INTEGER)
    IF size > 64 THEN size = 64
    IF size < 1 THEN size = 1
    buf.WindowSize = size
    buf.HeadIndex = 0
    buf.Count = 0
    buf.RunningSum = 0.0
    DIM i AS INTEGER
    FOR i = 0 TO 63
        buf.Samples(i) = 0.0
    NEXT i
END SUB

' PushMovingAverage: Adds new sample and returns updated rolling mean
FUNCTION PushMovingAverage(buf AS MovingAverageBuffer, sample AS DOUBLE) AS DOUBLE
    IF buf.Count < buf.WindowSize THEN
        buf.Samples(buf.HeadIndex) = sample
        buf.RunningSum = buf.RunningSum + sample
        buf.Count = buf.Count + 1
        buf.HeadIndex = (buf.HeadIndex + 1) MOD buf.WindowSize
        RETURN buf.RunningSum / buf.Count
    ELSE
        ' Evict oldest sample
        DIM oldest AS DOUBLE : oldest = buf.Samples(buf.HeadIndex)
        buf.RunningSum = buf.RunningSum - oldest + sample
        buf.Samples(buf.HeadIndex) = sample
        buf.HeadIndex = (buf.HeadIndex + 1) MOD buf.WindowSize
        RETURN buf.RunningSum / buf.WindowSize
    END IF
END FUNCTION
