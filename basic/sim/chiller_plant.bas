' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Central Chilled Water Plant & Cooling Tower Thermodynamic Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/chiller_plant.bas
' ==============================================================================
'
' This module implements the thermodynamic vapor compression refrigeration
' cycle and plant optimization for an industrial campus chilled water facility:
'   - Water-cooled centrifugal chillers using R-134a refrigerant
'   - Evaporator refrigeration capacity: Q_evap = m_dot * Cp * (T_chwr - T_chws)
'   - Carnot efficiency scaling for Coefficient of Performance (COP)
'   - Condenser thermal rejection: Q_cond = Q_evap + W_comp
'   - Induced-draft cooling tower with ambient wet-bulb approach dynamics
' ==============================================================================

TYPE CentrifugalChiller
    IsRunning       AS INTEGER ' 1 = Operating, 0 = Off
    CapacityTons    AS DOUBLE  ' Rated refrigeration tons (1 ton = 3.517 kW)
    EvaporatorLoadKW AS DOUBLE ' Current thermal cooling load Q_evap
    CompressorPowerKW AS DOUBLE' Electrical motor power draw W_comp
    CopEfficiency   AS DOUBLE  ' Coefficient of Performance COP (nominal 5.5 to 6.5)
    
    ChwsTempC       AS DOUBLE  ' Chilled water supply temperature (nominal 6.5 deg C)
    ChwrTempC       AS DOUBLE  ' Chilled water return temperature (nominal 12.5 deg C)
    ChwFlowLPS      AS DOUBLE  ' Chilled water volumetric flow (liters / sec)
    
    CwsTempC        AS DOUBLE  ' Condenser water supply from tower (nominal 29.5 deg C)
    CwrTempC        AS DOUBLE  ' Condenser water return to tower (nominal 35.0 deg C)
    CwFlowLPS       AS DOUBLE  ' Condenser water flow (liters / sec)
    
    VaneGuidePositionPct AS DOUBLE ' Inlet guide vane capacity throttling
END TYPE

TYPE ChillerPlantState
    Chillers(3)     AS CentrifugalChiller
    TotalTonsRefrig AS DOUBLE
    TotalPlantPowerKW AS DOUBLE
    OverallPlantKW_Ton AS DOUBLE ' Standard ASHRAE benchmark (0.55 to 0.75 kW/ton)
    
    AmbientDryBulbC AS DOUBLE
    AmbientWetBulbC AS DOUBLE  ' Critical cooling tower limit
    CoolingTowerFanHz AS DOUBLE' Tower fan VFD speed (0 to 60 Hz)
END TYPE

' InitializeChillerPlant: Sets up 3 x 1000-ton central plant
SUB InitializeChillerPlant(plant AS ChillerPlantState)
    plant.AmbientDryBulbC = 32.0   ' Summer design day
    plant.AmbientWetBulbC = 25.5
    plant.CoolingTowerFanHz = 50.0
    
    plant.TotalTonsRefrig = 1850.0
    plant.TotalPlantPowerKW = 1180.0
    plant.OverallPlantKW_Ton = 0.638
    
    DIM i AS INTEGER
    FOR i = 1 TO 3
        IF i <= 2 THEN
            plant.Chillers(i).IsRunning = 1
            plant.Chillers(i).VaneGuidePositionPct = 90.0
        ELSE
            plant.Chillers(i).IsRunning = 0
            plant.Chillers(i).VaneGuidePositionPct = 0.0
        END IF
        
        plant.Chillers(i).CapacityTons = 1000.0 ' 3517 kW rated
        plant.Chillers(i).EvaporatorLoadKW = 3250.0
        plant.Chillers(i).CompressorPowerKW = 530.0
        plant.Chillers(i).CopEfficiency = 6.13
        
        plant.Chillers(i).ChwsTempC = 6.7
        plant.Chillers(i).ChwrTempC = 12.2
        plant.Chillers(i).ChwFlowLPS = 141.0
        
        plant.Chillers(i).CwsTempC = 29.4
        plant.Chillers(i).CwrTempC = 34.8
        plant.Chillers(i).CwFlowLPS = 168.0
    NEXT i
END SUB

' StepChillerPlantEuler: Simulates refrigeration cycle energy balances
SUB StepChillerPlantEuler(plant AS ChillerPlantState, targetChwsC AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    ' 1. Cooling Tower Approach: CWS approaches AmbientWetBulbC as tower fans run
    ' Tower approach = CWS - WetBulb. Minimum approach at 60 Hz ~ 3.5 deg C
    DIM approachDegC AS DOUBLE
    approachDegC = 3.5 + (60.0 - plant.CoolingTowerFanHz) * 0.15
    DIM targetCwsC AS DOUBLE : targetCwsC = plant.AmbientWetBulbC + approachDegC
    
    plant.TotalPlantPowerKW = (plant.CoolingTowerFanHz / 60.0) * 45.0 ' 45 kW tower fan
    plant.TotalTonsRefrig = 0.0
    
    DIM i AS INTEGER
    FOR i = 1 TO 3
        IF plant.Chillers(i).IsRunning = 1 THEN
            ' Condenser water supply follows tower
            plant.Chillers(i).CwsTempC = plant.Chillers(i).CwsTempC + ((targetCwsC - plant.Chillers(i).CwsTempC) / 30.0) * dtSec
            
            ' Slew guide vanes towards target CHWS
            DIM tempErr AS DOUBLE : tempErr = plant.Chillers(i).ChwsTempC - targetChwsC
            plant.Chillers(i).VaneGuidePositionPct = ClampValue(plant.Chillers(i).VaneGuidePositionPct + 0.8 * tempErr * dtSec, 20.0, 100.0)
            
            ' Cooling load: Q_evap = (Vanes / 100) * RatedCapacity
            plant.Chillers(i).EvaporatorLoadKW = (plant.Chillers(i).VaneGuidePositionPct / 100.0) * (plant.Chillers(i).CapacityTons * 3.517)
            
            ' Carnot-based COP calculation: COP = eta * (T_evap / (T_cond - T_evap))
            ' Convert to Kelvin
            DIM tEvapK AS DOUBLE : tEvapK = plant.Chillers(i).ChwsTempC + 273.15
            DIM tCondK AS DOUBLE : tCondK = plant.Chillers(i).CwrTempC + 273.15
            DIM deltaTK AS DOUBLE : deltaTK = tCondK - tEvapK
            IF deltaTK < 10.0 THEN deltaTK = 10.0
            
            DIM carnotCop AS DOUBLE : carnotCop = tEvapK / deltaTK
            plant.Chillers(i).CopEfficiency = carnotCop * 0.52 ' 52% Carnot efficiency factor
            IF plant.Chillers(i).CopEfficiency < 2.0 THEN plant.Chillers(i).CopEfficiency = 2.0
            
            ' Compressor power draw: W_comp = Q_evap / COP
            plant.Chillers(i).CompressorPowerKW = plant.Chillers(i).EvaporatorLoadKW / plant.Chillers(i).CopEfficiency
            
            ' Condenser heat rejection: Q_cond = Q_evap + W_comp
            DIM qCondKW AS DOUBLE : qCondKW = plant.Chillers(i).EvaporatorLoadKW + plant.Chillers(i).CompressorPowerKW
            ' Condenser water delta T: Q = m * Cp * deltaT => deltaT = Q / (m * 4.184)
            DIM cwDeltaT AS DOUBLE : cwDeltaT = qCondKW / (plant.Chillers(i).CwFlowLPS * 4.184)
            plant.Chillers(i).CwrTempC = plant.Chillers(i).CwsTempC + cwDeltaT
            
            ' Chilled water return delta T: deltaT = Q_evap / (m * 4.184)
            DIM chwDeltaT AS DOUBLE : chwDeltaT = plant.Chillers(i).EvaporatorLoadKW / (plant.Chillers(i).ChwFlowLPS * 4.184)
            plant.Chillers(i).ChwsTempC = plant.Chillers(i).ChwrTempC - chwDeltaT
            
            DIM tons AS DOUBLE : tons = plant.Chillers(i).EvaporatorLoadKW / 3.517
            plant.TotalTonsRefrig = plant.TotalTonsRefrig + tons
            plant.TotalPlantPowerKW = plant.TotalPlantPowerKW + plant.Chillers(i).CompressorPowerKW
        END IF
    NEXT i
    
    IF plant.TotalTonsRefrig > 10.0 THEN
        plant.OverallPlantKW_Ton = plant.TotalPlantPowerKW / plant.TotalTonsRefrig
    ELSE
        plant.OverallPlantKW_Ton = 0.0
    END IF
END SUB
