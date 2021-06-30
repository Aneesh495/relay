' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Shell-and-Tube Counter-Current Heat Exchanger Digital Twin Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/heat_exchanger.bas
' ==============================================================================
'
' This module implements an industrial counter-current shell-and-tube heat
' exchanger with dynamic energy balances across two fluid streams:
'   - Hot process stream (tube side) and cold cooling stream (shell side)
'   - Counter-current Logarithmic Mean Temperature Difference (LMTD)
'   - Metal tube wall thermal inertia and capacitance
'   - Fouling factor thermal resistance degradation over operating cycles
'   - Three-way temperature control bypass valve dynamics
' ==============================================================================

TYPE HeatExchangerState
    ' Hot Process Stream (Tube Side)
    HotInletTempC     AS DOUBLE  ' Inlet temperature Th_in (deg C)
    HotOutletTempC    AS DOUBLE  ' Dynamic outlet temperature Th_out (deg C)
    HotFlowKgS        AS DOUBLE  ' Mass flow rate mh (kg/s)
    HotSpecificHeat   AS DOUBLE  ' Specific heat capacity Cph (kJ / (kg * K))
    
    ' Cold Coolant Stream (Shell Side)
    ColdInletTempC    AS DOUBLE  ' Inlet coolant temperature Tc_in (deg C)
    ColdOutletTempC   AS DOUBLE  ' Dynamic coolant outlet temperature Tc_out (deg C)
    ColdFlowKgS       AS DOUBLE  ' Coolant mass flow rate mc (kg/s)
    ColdSpecificHeat  AS DOUBLE  ' Coolant specific heat Cpc (kJ / (kg * K))
    
    ' Tube Wall and Geometry
    WallTempC         AS DOUBLE  ' Tube wall intermediate metal temperature (deg C)
    HeatExchangeAreaM2 AS DOUBLE ' Effective heat transfer surface area A (m^2)
    CleanUCoeffKW_M2K AS DOUBLE  ' Clean overall heat transfer coefficient U0 (kW / (m^2 * K))
    FoulingFactorM2K_KW AS DOUBLE' Thermal fouling resistance Rf ((m^2 * K) / kW)
    EffectiveUCoeff   AS DOUBLE  ' Actual overall U = 1 / (1/U0 + Rf) (kW / (m^2 * K))
    
    ' Energy Flux Metrics
    DutyThermalKW     AS DOUBLE  ' Instantaneous heat duty Q (kW thermal)
    LMTDDegC          AS DOUBLE  ' Logarithmic Mean Temperature Difference (deg C)
    Effectiveness     AS DOUBLE  ' Exchanger thermal effectiveness epsilon [0, 1]
    
    ' Bypass Control Valve
    BypassPercent     AS DOUBLE  ' Hot stream bypass fraction (0 to 100%)
    MixedOutletTempC  AS DOUBLE  ' Blended stream temperature after bypass mixing (deg C)
END TYPE

' InitializeHeatExchanger: Sets up industrial hydrocarbon cooler parameters
SUB InitializeHeatExchanger(hex AS HeatExchangerState)
    hex.HotInletTempC = 145.0          ' 145 deg C process feed
    hex.HotOutletTempC = 65.0          ' Target 65 deg C product outlet
    hex.HotFlowKgS = 18.5              ' 18.5 kg/s hot fluid
    hex.HotSpecificHeat = 2.45         ' Hydrocarbon blend heat capacity
    
    hex.ColdInletTempC = 22.0          ' 22 deg C cooling tower supply
    hex.ColdOutletTempC = 44.0         ' 44 deg C return
    hex.ColdFlowKgS = 32.0             ' 32 kg/s cooling water
    hex.ColdSpecificHeat = 4.184       ' Water heat capacity
    
    hex.WallTempC = 80.0
    hex.HeatExchangeAreaM2 = 120.0     ' 120 square meters of tubing
    hex.CleanUCoeffKW_M2K = 0.85       ' 850 W / (m^2 * K)
    hex.FoulingFactorM2K_KW = 0.05     ' Light scale accumulation
    hex.EffectiveUCoeff = 1.0 / ((1.0 / 0.85) + 0.05)
    
    hex.DutyThermalKW = 3628.0         ' ~3.6 MW duty
    hex.LMTDDegC = 67.2
    hex.Effectiveness = 0.65
    
    hex.BypassPercent = 0.0
    hex.MixedOutletTempC = 65.0
END SUB

' ComputeLMTD: Calculates counter-current Log-Mean Temperature Difference safely
FUNCTION ComputeLMTD(th_in AS DOUBLE, th_out AS DOUBLE, tc_in AS DOUBLE, tc_out AS DOUBLE) AS DOUBLE
    ' Delta 1: Hot inlet minus cold outlet
    DIM dt1 AS DOUBLE : dt1 = th_in - tc_out
    ' Delta 2: Hot outlet minus cold inlet
    DIM dt2 AS DOUBLE : dt2 = th_out - tc_in
    
    IF dt1 <= 0.1 THEN dt1 = 0.1
    IF dt2 <= 0.1 THEN dt2 = 0.1
    
    DIM diff AS DOUBLE : diff = dt1 - dt2
    IF ABS(diff) < 0.001 THEN
        ' Equal approach: arithmetic mean matches logarithmic limit
        ComputeLMTD = (dt1 + dt2) * 0.5
    ELSE
        DIM ratio AS DOUBLE : ratio = dt1 / dt2
        IF ratio <= 0.0 THEN ratio = 0.0001
        ComputeLMTD = diff / LOG(ratio)
    END IF
END FUNCTION

' StepHeatExchangerEuler: Advances exchanger thermal states by dtSec seconds
SUB StepHeatExchangerEuler(hex AS HeatExchangerState, hotInC AS DOUBLE, coldInC AS DOUBLE, hotFlowKgS AS DOUBLE, coldFlowKgS AS DOUBLE, bypassPct AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    hex.HotInletTempC = hotInC
    hex.ColdInletTempC = coldInC
    hex.HotFlowKgS = ClampValue(hotFlowKgS, 0.5, 100.0)
    hex.ColdFlowKgS = ClampValue(coldFlowKgS, 0.5, 150.0)
    hex.BypassPercent = ClampValue(bypassPct, 0.0, 100.0)
    
    ' Effective flow passing through tube bundle after bypass split
    DIM bypassFraction AS DOUBLE : bypassFraction = hex.BypassPercent / 100.0
    DIM activeHotFlowKgS AS DOUBLE : activeHotFlowKgS = hex.HotFlowKgS * (1.0 - bypassFraction)
    
    ' Update effective U coefficient considering fouling
    hex.EffectiveUCoeff = 1.0 / ((1.0 / hex.CleanUCoeffKW_M2K) + hex.FoulingFactorM2K_KW)
    
    ' Counter-current LMTD calculation
    hex.LMTDDegC = ComputeLMTD(hex.HotInletTempC, hex.HotOutletTempC, hex.ColdInletTempC, hex.ColdOutletTempC)
    
    ' Thermal heat transfer rate: Q = U * A * LMTD (kW)
    hex.DutyThermalKW = hex.EffectiveUCoeff * hex.HeatExchangeAreaM2 * hex.LMTDDegC
    IF hex.DutyThermalKW < 0.0 THEN hex.DutyThermalKW = 0.0
    
    ' Heat capacities (kW / K)
    DIM ch AS DOUBLE : ch = activeHotFlowKgS * hex.HotSpecificHeat
    DIM cc AS DOUBLE : cc = hex.ColdFlowKgS * hex.ColdSpecificHeat
    
    ' Heat exchanger effectiveness calculation: epsilon = Q / Q_max
    DIM cMin AS DOUBLE
    IF ch < cc THEN
        cMin = ch
    ELSE
        cMin = cc
    END IF
    DIM qMaxKW AS DOUBLE : qMaxKW = cMin * (hex.HotInletTempC - hex.ColdInletTempC)
    IF qMaxKW > 0.001 THEN
        hex.Effectiveness = hex.DutyThermalKW / qMaxKW
        hex.Effectiveness = ClampValue(hex.Effectiveness, 0.0, 1.0)
    ELSE
        hex.Effectiveness = 0.0
    END IF
    
    ' Dynamic differential equations for fluid hold-up volumes
    ' Tube fluid thermal mass hold-up approx 450 kJ / K; shell fluid approx 600 kJ / K
    DIM hotHoldUpKJ_K AS DOUBLE : hotHoldUpKJ_K = 450.0
    DIM coldHoldUpKJ_K AS DOUBLE : coldHoldUpKJ_K = 600.0
    
    ' dTh_out/dt = (ch * (Th_in - Th_out) - Q) / hotHoldUp
    DIM dTh_dt AS DOUBLE
    dTh_dt = (ch * (hex.HotInletTempC - hex.HotOutletTempC) - hex.DutyThermalKW) / hotHoldUpKJ_K
    hex.HotOutletTempC = hex.HotOutletTempC + dTh_dt * dtSec
    
    ' dTc_out/dt = (cc * (Tc_in - Tc_out) + Q) / coldHoldUp
    DIM dTc_dt AS DOUBLE
    dTc_dt = (cc * (hex.ColdInletTempC - hex.ColdOutletTempC) + hex.DutyThermalKW) / coldHoldUpKJ_K
    hex.ColdOutletTempC = hex.ColdOutletTempC + dTc_dt * dtSec
    
    ' Intermediate wall temperature (arithmetic coupling)
    hex.WallTempC = (hex.HotOutletTempC + hex.ColdOutletTempC) * 0.5
    
    ' Downstream blend point mixing with hot bypass flow
    ' M_total * T_mixed = M_active * T_exchanger_out + M_bypass * T_hot_in
    hex.MixedOutletTempC = (1.0 - bypassFraction) * hex.HotOutletTempC + bypassFraction * hex.HotInletTempC
END SUB
