' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' ASHRAE Fundamentals Psychrometric Thermodynamics & Moist Air Properties
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/hvac/psychrometrics.bas
' ==============================================================================
'
' This module implements the ASHRAE psychrometric equations of state for
' heating, ventilation, and air-conditioning (HVAC) environmental control:
'   - Saturated water vapor pressure P_ws(T) via Magnus-Tetens correlation
'   - Humidity ratio W (kg water vapor per kg dry air)
'   - Specific enthalpy h of moist air (kJ / kg dry air)
'   - Dew point temperature T_dp from partial vapor pressure
'   - Wet-bulb temperature iterative thermodynamic equilibrium
' ==============================================================================

CONST PATM_KPA = 101.325 ' Standard sea-level barometric pressure (kPa)

' ComputeSatVaporPressureKPa: Magnus-Tetens formula for water vapor saturation
FUNCTION ComputeSatVaporPressureKPa(tempC AS DOUBLE) AS DOUBLE
    ' P_ws(T) = 0.61078 * exp((17.27 * T) / (T + 237.3))
    DIM exponent AS DOUBLE : exponent = (17.27 * tempC) / (tempC + 237.3)
    ComputeSatVaporPressureKPa = 0.61078 * EXP(exponent)
END FUNCTION

' ComputeHumidityRatio: W = 0.62198 * P_w / (P_atm - P_w)
FUNCTION ComputeHumidityRatio(tempC AS DOUBLE, relativeHumidityPct AS DOUBLE) AS DOUBLE
    DIM pWs AS DOUBLE : pWs = ComputeSatVaporPressureKPa(tempC)
    DIM pW AS DOUBLE : pW = (relativeHumidityPct / 100.0) * pWs
    
    DIM denom AS DOUBLE : denom = PATM_KPA - pW
    IF denom < 1.0 THEN denom = 1.0
    
    ComputeHumidityRatio = 0.62198 * (pW / denom)
END FUNCTION

' ComputeMoistAirEnthalpy: h = 1.006 * T + W * (2501.0 + 1.86 * T) in kJ / kg
FUNCTION ComputeMoistAirEnthalpy(tempC AS DOUBLE, humidityRatioW AS DOUBLE) AS DOUBLE
    DIM sensibleDryAir AS DOUBLE : sensibleDryAir = 1.006 * tempC
    DIM latentMoisture AS DOUBLE : latentMoisture = humidityRatioW * (2501.0 + 1.86 * tempC)
    ComputeMoistAirEnthalpy = sensibleDryAir + latentMoisture
END FUNCTION

' ComputeDewPointTempC: Approximates dew point from dry-bulb temp and relative humidity
FUNCTION ComputeDewPointTempC(tempC AS DOUBLE, relativeHumidityPct AS DOUBLE) AS DOUBLE
    IF relativeHumidityPct <= 0.1 THEN relativeHumidityPct = 0.1
    DIM rhFrac AS DOUBLE : rhFrac = relativeHumidityPct / 100.0
    DIM gammaVal AS DOUBLE : gammaVal = ((17.27 * tempC) / (tempC + 237.3)) + LOG(rhFrac)
    DIM denom AS DOUBLE : denom = 17.27 - gammaVal
    IF denom < 0.1 THEN denom = 0.1
    ComputeDewPointTempC = (237.3 * gammaVal) / denom
END FUNCTION
