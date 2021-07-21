' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Heavy-Duty Industrial Gas Turbine Digital Twin Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/gas_turbine.bas
' ==============================================================================
'
' This module implements the dynamic Brayton open-cycle thermodynamic model
' for an industrial heavy-frame single-shaft gas turbine:
'   - Multi-stage axial air compressor pressure ratio and mass flow
'   - Variable Inlet Guide Vanes (VIGV) modulating airflow
'   - Combustor natural gas fuel firing rate and flame temperature
'   - High-temperature expander turbine enthalpy drop and shaft power
'   - Exhaust gas temperature (EGT) thermodynamic limit controller
'   - Rotor inertia and speed governor (nominal 3000 / 3600 RPM)
' ==============================================================================

TYPE GasTurbineState
    ' Rotor Mechanics
    SpeedRpm        AS DOUBLE  ' Shaft rotational speed (nominal 3600 RPM)
    SpeedPercent    AS DOUBLE  ' % of rated synchronous speed (nominal 100.0%)
    RotorInertiaKgM2 AS DOUBLE ' Rotor mechanical moment of inertia
    MechanicalPowerMW AS DOUBLE' Shaft net power output (MW)
    ElectricalPowerMW AS DOUBLE' Generator output after efficiency loss
    
    ' Air Path & Compressor
    AmbientTempC    AS DOUBLE  ' Ambient air temperature (15.0 deg C)
    AmbientPressureBar AS DOUBLE' Atmospheric pressure (1.013 bar)
    VigvAngleDeg    AS DOUBLE  ' Variable inlet guide vane angle (-42 to 0 deg)
    AirFlowKgS      AS DOUBLE  ' Compressor air mass flow (kg/s)
    CompressorDischargePressBar AS DOUBLE ' P_cd (nominal 16.5 bar)
    CompressorDischargeTempC AS DOUBLE    ' T_cd (nominal 410.0 deg C)
    
    ' Combustor & Fuel System
    FuelGasFlowKgS  AS DOUBLE  ' Natural gas fuel mass flow (nominal 9.5 kg/s)
    CombustorFiringTempC AS DOUBLE ' T_fire (nominal 1320.0 deg C)
    FuelValveOP     AS DOUBLE  ' Fuel gas control valve position (0 to 100%)
    
    ' Turbine Expander & Exhaust
    ExhaustTempC    AS DOUBLE  ' Exhaust gas temperature EGT (nominal 580.0 deg C)
    ExhaustTempSP   AS DOUBLE  ' EGT temperature limit control setpoint
    ThermalEfficiencyPct AS DOUBLE ' Net lower heating value thermal efficiency
    FlameDetector   AS INTEGER ' 1 = Flame verified by optical UV/IR sensors
    TurbineTripped  AS INTEGER ' 1 = Emergency shutdown active
END TYPE

' InitializeGasTurbine: Configures 180 MW F-class industrial gas turbine
SUB InitializeGasTurbine(gt AS GasTurbineState)
    gt.SpeedRpm = 3600.0
    gt.SpeedPercent = 100.0
    gt.RotorInertiaKgM2 = 28500.0
    gt.MechanicalPowerMW = 182.0
    gt.ElectricalPowerMW = 178.5
    
    gt.AmbientTempC = 15.0
    gt.AmbientPressureBar = 1.013
    gt.VigvAngleDeg = 0.0          ' Fully open
    gt.AirFlowKgS = 480.0          ' 480 kg/s compressor flow
    gt.CompressorDischargePressBar = 16.5
    gt.CompressorDischargeTempC = 412.0
    
    gt.FuelGasFlowKgS = 9.8        ' Methane LHV ~ 50 MJ/kg
    gt.CombustorFiringTempC = 1325.0
    gt.FuelValveOP = 72.0
    
    gt.ExhaustTempC = 582.0
    gt.ExhaustTempSP = 585.0       ' EGT isotherm limit
    gt.ThermalEfficiencyPct = 37.2
    gt.FlameDetector = 1
    gt.TurbineTripped = 0
END SUB

' StepGasTurbineEuler: Advances thermodynamic gas turbine states by dtSec seconds
SUB StepGasTurbineEuler(gt AS GasTurbineState, targetMw AS DOUBLE, gridFreqHz AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 OR gt.TurbineTripped = 1 THEN EXIT SUB
    
    ' 1. Overspeed and Over-temperature Trip Protection
    IF gt.SpeedRpm > 3960.0 OR gt.ExhaustTempC > 650.0 THEN
        gt.TurbineTripped = 1
        gt.FuelGasFlowKgS = 0.0
        gt.FuelValveOP = 0.0
        gt.ElectricalPowerMW = 0.0
        gt.MechanicalPowerMW = 0.0
        PRINT "[TRIP] Gas Turbine Tripped! Speed:"; gt.SpeedRpm; "RPM, EGT:"; gt.ExhaustTempC; "deg C"
        EXIT SUB
    END IF
    
    ' 2. Speed / Frequency Droop Governor (4% Regulation)
    ' Standard droop: delta_speed = (f_actual - f_grid) / f_rated
    DIM speedErrorPct AS DOUBLE : speedErrorPct = ((gridFreqHz - 60.00) / 60.00) * 100.0
    DIM governorDemandPct AS DOUBLE : governorDemandPct = (targetMw / 185.0) * 100.0 - (speedErrorPct * 25.0)
    
    ' 3. Exhaust Temperature Control Override (Min-Select Gate)
    ' If EGT approaches limit, cut back fuel
    DIM egtError AS DOUBLE : egtError = gt.ExhaustTempC - gt.ExhaustTempSP
    DIM egtCutbackPct AS DOUBLE : egtCutbackPct = 0.0
    IF egtError > 0.0 THEN
        egtCutbackPct = egtError * 2.5
    END IF
    
    DIM netFuelDemand AS DOUBLE : netFuelDemand = governorDemandPct - egtCutbackPct
    gt.FuelValveOP = ClampValue(netFuelDemand, 5.0, 100.0)
    
    ' First-order fuel valve actuator lag (tau = 0.4 sec)
    DIM targetFuelKgS AS DOUBLE : targetFuelKgS = (gt.FuelValveOP / 100.0) * 13.5
    gt.FuelGasFlowKgS = gt.FuelGasFlowKgS + ((targetFuelKgS - gt.FuelGasFlowKgS) / 0.4) * dtSec
    
    ' 4. Thermodynamic Combustion & Expansion
    ' Heat input Q_in (MW) = FuelKgS * LHV (50 MJ/kg)
    DIM heatInMW AS DOUBLE : heatInMW = gt.FuelGasFlowKgS * 50.0
    
    ' Turbine gross power = Expander power - Compressor power
    ' Compressor consumes approx 55% of expander gross output
    DIM grossPowerMW AS DOUBLE : grossPowerMW = heatInMW * 0.85
    DIM compPowerMW AS DOUBLE : compPowerMW = grossPowerMW * 0.58
    gt.MechanicalPowerMW = grossPowerMW - compPowerMW
    IF gt.MechanicalPowerMW < 0.0 THEN gt.MechanicalPowerMW = 0.0
    
    gt.ElectricalPowerMW = gt.MechanicalPowerMW * 0.985 ' 98.5% generator efficiency
    
    ' Thermal efficiency: P_elec / Q_in
    IF heatInMW > 1.0 THEN
        gt.ThermalEfficiencyPct = (gt.ElectricalPowerMW / heatInMW) * 100.0
    ELSE
        gt.ThermalEfficiencyPct = 0.0
    END IF
    
    ' 5. Temperatures and Pressures
    gt.CombustorFiringTempC = 400.0 + (gt.FuelGasFlowKgS / 10.0) * 950.0
    gt.ExhaustTempC = gt.CombustorFiringTempC - (gt.MechanicalPowerMW / 180.0) * 750.0
    IF gt.ExhaustTempC < 150.0 THEN gt.ExhaustTempC = 150.0
    
    ' 6. Shaft Speed Dynamics (Swing equation: J * omega * d_omega/dt = P_mech - P_elec)
    DIM powerImbalanceMW AS DOUBLE
    IF targetMw > 0.0 THEN
        powerImbalanceMW = gt.MechanicalPowerMW - targetMw
    ELSE
        powerImbalanceMW = gt.MechanicalPowerMW - gt.ElectricalPowerMW
    END IF
    
    DIM dSpeedRpm AS DOUBLE
    dSpeedRpm = (powerImbalanceMW * 1.0E6 / (gt.RotorInertiaKgM2 * 377.0)) * dtSec * 9.55
    gt.SpeedRpm = ClampValue(gt.SpeedRpm + dSpeedRpm, 0.0, 4200.0)
    gt.SpeedPercent = (gt.SpeedRpm / 3600.0) * 100.0
END SUB
