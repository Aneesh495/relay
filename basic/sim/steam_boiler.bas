' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Industrial Steam Drum Boiler Digital Twin Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/steam_boiler.bas
' ==============================================================================
'
' This module implements an industrial natural-circulation steam boiler with
' non-linear drum dynamics, including:
'   - Drum water mass and thermal energy conservation
'   - Two-phase riser bubble volume and evaporation rate
'   - Shrink and swell non-minimum phase level phenomena
'   - Superheater header temperature with attemperator spray cooling
'   - Dual-stage overpressure safety relief valve discharge
' ==============================================================================

TYPE SteamBoilerState
    ' Drum Pressure and Temperature
    DrumPressureBar   AS DOUBLE  ' Drum internal pressure (bar)
    DrumTempC         AS DOUBLE  ' Drum saturation temperature (deg C)
    
    ' Drum Fluid Inventories
    DrumWaterMassKg   AS DOUBLE  ' Liquid water mass in drum (kg)
    DrumSteamMassKg   AS DOUBLE  ' Saturated vapor mass in drum (kg)
    LiquidLevelMm     AS DOUBLE  ' Indicated drum liquid level (-500 to +500 mm relative to normal)
    BubbleVolumeM3    AS DOUBLE  ' Submerged steam bubble volume in drum (causes swell/shrink)
    
    ' Mass Flow Rates (kg/s)
    FeedwaterFlowKgS  AS DOUBLE  ' Feedwater inlet mass flow rate
    EvaporationRateKgS AS DOUBLE ' Boiling evaporation rate from riser tubes
    SteamDemandFlowKgS AS DOUBLE ' Main steam header consumption flow
    AttemperatorFlowKgS AS DOUBLE' Spray water flow to superheater
    SafetyValveFlowKgS AS DOUBLE ' Relief valve venting mass flow
    
    ' Superheater Section
    SuperheatTempC    AS DOUBLE  ' Final superheated steam temperature (deg C)
    SuperheatTempSP   AS DOUBLE  ' Desired superheat setpoint (deg C)
    
    ' Thermal and Structural Geometry
    FurnaceFiringMW   AS DOUBLE  ' Thermal heat release from combustion (MW thermal)
    DrumVolumeM3      AS DOUBLE  ' Total drum internal volume (m^3)
    NormalWaterVolM3  AS DOUBLE  ' Normal liquid operating volume (m^3)
    SafetyReliefSetBar AS DOUBLE ' Safety relief valve pop setpoint (bar)
END TYPE

' InitializeSteamBoiler: Configures typical 50 MW industrial utility boiler
SUB InitializeSteamBoiler(boiler AS SteamBoilerState)
    boiler.DrumPressureBar = 42.0     ' 42 bar operating pressure
    boiler.DrumTempC = 253.2          ' Saturation temperature at 42 bar
    
    boiler.DrumVolumeM3 = 18.0        ' Total internal volume
    boiler.NormalWaterVolM3 = 9.0     ' Normal 50% water level
    
    ' Water density approx 800 kg/m^3 at 250 deg C; steam density approx 21 kg/m^3
    boiler.DrumWaterMassKg = 7200.0   ' 9.0 m^3 * 800 kg/m^3
    boiler.DrumSteamMassKg = 189.0    ' 9.0 m^3 * 21 kg/m^3
    boiler.LiquidLevelMm = 0.0        ' Centered at normal operating level (NWL)
    boiler.BubbleVolumeM3 = 0.45      ' Baseline bubble hold-up
    
    boiler.FeedwaterFlowKgS = 25.0    ' 90 tonnes/hour normal rating
    boiler.EvaporationRateKgS = 25.0
    boiler.SteamDemandFlowKgS = 25.0
    boiler.AttemperatorFlowKgS = 1.2
    boiler.SafetyValveFlowKgS = 0.0
    
    boiler.SuperheatTempC = 440.0     ' Target 440 deg C superheat
    boiler.SuperheatTempSP = 440.0
    boiler.FurnaceFiringMW = 65.0     ' 65 MW thermal firing rate
    boiler.SafetyReliefSetBar = 50.0  ' Trip / pop at 50 bar
END SUB

' StepSteamBoilerEuler: Advances boiler states by dtSec seconds
SUB StepSteamBoilerEuler(boiler AS SteamBoilerState, firingMW AS DOUBLE, feedwaterKgS AS DOUBLE, steamDemandKgS AS DOUBLE, sprayKgS AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    ' Bound physical actuator inputs
    boiler.FurnaceFiringMW = ClampValue(firingMW, 5.0, 85.0)
    boiler.FeedwaterFlowKgS = ClampValue(feedwaterKgS, 0.0, 50.0)
    boiler.SteamDemandFlowKgS = ClampValue(steamDemandKgS, 0.0, 50.0)
    boiler.AttemperatorFlowKgS = ClampValue(sprayKgS, 0.0, 5.0)
    
    ' 1. Evaporation Rate from Riser Tubes:
    ' Latent heat of vaporization h_fg approx 1670 kJ/kg at 42 bar
    DIM latentHeatKJ_Kg AS DOUBLE : latentHeatKJ_Kg = 1670.0
    DIM heatEffectiveMW AS DOUBLE : heatEffectiveMW = boiler.FurnaceFiringMW * 0.88 ' 88% thermal efficiency
    DIM targetEvapKgS AS DOUBLE : targetEvapKgS = (heatEffectiveMW * 1000.0) / latentHeatKJ_Kg
    
    ' First-order thermal lag of waterwall riser tubes (tau approx 15 seconds)
    DIM tauRiserSec AS DOUBLE : tauRiserSec = 15.0
    boiler.EvaporationRateKgS = boiler.EvaporationRateKgS + ((targetEvapKgS - boiler.EvaporationRateKgS) / tauRiserSec) * dtSec
    
    ' 2. Overpressure Safety Relief Valve Mechanics
    IF boiler.DrumPressureBar >= boiler.SafetyReliefSetBar THEN
        DIM overpressureBar AS DOUBLE : overpressureBar = boiler.DrumPressureBar - boiler.SafetyReliefSetBar
        boiler.SafetyValveFlowKgS = overpressureBar * 8.0 ' 8 kg/s per bar overpressure
    ELSE
        boiler.SafetyValveFlowKgS = 0.0
    END IF
    
    ' 3. Net Vapor Inventory and Drum Pressure Dynamics:
    ' Vapor mass balance: dM_steam/dt = Evaporation - SteamDemand - SafetyValveFlow
    DIM totalVaporOutKgS AS DOUBLE : totalVaporOutKgS = boiler.SteamDemandFlowKgS + boiler.SafetyValveFlowKgS
    DIM dM_steam_dt AS DOUBLE : dM_steam_dt = boiler.EvaporationRateKgS - totalVaporOutKgS
    boiler.DrumSteamMassKg = boiler.DrumSteamMassKg + dM_steam_dt * dtSec
    IF boiler.DrumSteamMassKg < 20.0 THEN boiler.DrumSteamMassKg = 20.0
    
    ' Drum pressure compliance: dP/dt proportional to net vapor generation
    ' Bulk steam elasticity factor approx 0.08 bar per kg of excess vapor
    DIM dP_dt AS DOUBLE : dP_dt = dM_steam_dt * 0.08
    boiler.DrumPressureBar = boiler.DrumPressureBar + dP_dt * dtSec
    IF boiler.DrumPressureBar < 1.0 THEN boiler.DrumPressureBar = 1.0
    
    ' Saturation temperature approximation (Magnus-Tetens formula derivative)
    boiler.DrumTempC = 100.0 + 23.5 * SQR(boiler.DrumPressureBar)
    
    ' 4. Liquid Water Mass Inventory:
    ' dM_water/dt = FeedwaterFlow - EvaporationRate
    DIM dM_water_dt AS DOUBLE : dM_water_dt = boiler.FeedwaterFlowKgS - boiler.EvaporationRateKgS
    boiler.DrumWaterMassKg = boiler.DrumWaterMassKg + dM_water_dt * dtSec
    IF boiler.DrumWaterMassKg < 1000.0 THEN boiler.DrumWaterMassKg = 1000.0
    
    ' 5. Shrink and Swell Level Dynamics:
    ' Rapid depressurization causes submerged steam bubbles to expand (swell).
    ' Sudden cold feedwater injection collapses bubbles (shrink).
    ' Bubble volume dynamics: tau_b * dV_b/dt = -V_b + k_evap * Evaporation - k_p * dP/dt - k_fw * FeedwaterFlow
    DIM targetBubbleVolM3 AS DOUBLE
    targetBubbleVolM3 = 0.018 * boiler.EvaporationRateKgS - 0.06 * dP_dt - 0.008 * boiler.FeedwaterFlowKgS
    IF targetBubbleVolM3 < 0.05 THEN targetBubbleVolM3 = 0.05
    
    DIM tauBubbleSec AS DOUBLE : tauBubbleSec = 6.0
    boiler.BubbleVolumeM3 = boiler.BubbleVolumeM3 + ((targetBubbleVolM3 - boiler.BubbleVolumeM3) / tauBubbleSec) * dtSec
    
    ' Net indicated water volume = true liquid volume + submerged bubble volume
    ' Liquid density approx 800 kg/m^3
    DIM liquidWaterVolM3 AS DOUBLE : liquidWaterVolM3 = boiler.DrumWaterMassKg / 800.0
    DIM apparentTotalVolM3 AS DOUBLE : apparentTotalVolM3 = liquidWaterVolM3 + boiler.BubbleVolumeM3
    
    ' Level deviation in millimeters: cross-sectional area of drum surface approx 7.5 m^2
    DIM drumWaterAreaM2 AS DOUBLE : drumWaterAreaM2 = 7.5
    DIM normalTotalVolM3 AS DOUBLE : normalTotalVolM3 = boiler.NormalWaterVolM3 + 0.45
    boiler.LiquidLevelMm = ((apparentTotalVolM3 - normalTotalVolM3) / drumWaterAreaM2) * 1000.0
    boiler.LiquidLevelMm = ClampValue(boiler.LiquidLevelMm, -600.0, 600.0)
    
    ' 6. Superheater Outlet Temperature Dynamics:
    ' Convective heat uptake from flue gas heats steam to ~470 deg C before spray
    DIM rawSuperheatTempC AS DOUBLE : rawSuperheatTempC = boiler.DrumTempC + (boiler.FurnaceFiringMW / 65.0) * 200.0
    ' Attemperator spray cooling effect: approx 28 deg C temperature drop per kg/s spray
    DIM sprayCoolingDegC AS DOUBLE : sprayCoolingDegC = boiler.AttemperatorFlowKgS * 28.0
    DIM superheatTargetC AS DOUBLE : superheatTargetC = rawSuperheatTempC - sprayCoolingDegC
    
    DIM tauSuperheatSec AS DOUBLE : tauSuperheatSec = 20.0
    boiler.SuperheatTempC = boiler.SuperheatTempC + ((superheatTargetC - boiler.SuperheatTempC) / tauSuperheatSec) * dtSec
END SUB
