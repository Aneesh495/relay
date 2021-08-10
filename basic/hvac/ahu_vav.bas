' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Air Handling Unit (AHU) & VAV Terminal Box Automation (ASHRAE Guideline 36)
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/hvac/ahu_vav.bas
' ==============================================================================
'
' This module implements high-efficiency commercial building HVAC automation
' compliant with ASHRAE Guideline 36 high-performance sequences of operation:
'   - Air-side free cooling economizer damper sequencing
'   - Mixed Air Temperature (MAT) adiabatic mass balance
'   - Outdoor Air Temperature (OAT) Supply Air Temperature (SAT) reset schedule
'   - VAV duct static pressure Trim and Respond optimization
'   - Indoor Air Quality (IAQ) Demand Controlled Ventilation (DCV) on CO2
' ==============================================================================

TYPE AhuControllerState
    ' Air Stream Temperatures (deg C)
    OutdoorAirTempC  AS DOUBLE  ' OAT
    ReturnAirTempC   AS DOUBLE  ' RAT (nominal 24.0 deg C)
    MixedAirTempC    AS DOUBLE  ' MAT
    SupplyAirTempC   AS DOUBLE  ' SAT
    SupplyAirTempSP  AS DOUBLE  ' Dynamic setpoint from reset schedule
    
    ' Damper & Valve Positions (0 to 100%)
    OutdoorDamperOP  AS DOUBLE  ' Outdoor air damper
    ReturnDamperOP   AS DOUBLE  ' Return air damper (100 - OutdoorDamperOP)
    CoolingCoilValveOP AS DOUBLE' Chilled water valve
    HeatingCoilValveOP AS DOUBLE' Hot water valve
    SupplyFanSpeedHz AS DOUBLE  ' Supply fan VFD frequency
    
    ' Airflow & Pressures
    SupplyAirFlowCFM AS DOUBLE  ' Cubic feet per minute
    DuctStaticPressInWg AS DOUBLE ' Duct static pressure (inches water gauge)
    StaticPressSPInWg AS DOUBLE ' Dynamic static pressure setpoint
    IndoorCo2Ppm     AS DOUBLE  ' Zone CO2 concentration (target < 800 ppm)
    
    ' Operational Modes
    EconomizerActive AS INTEGER ' 1 = Free cooling engaged
    FreezeStatTripped AS INTEGER' 1 = MAT < 3.5 deg C low-temp freeze trip
END TYPE

' InitializeAhuController: Sets up 25,000 CFM commercial AHU
SUB InitializeAhuController(ahu AS AhuControllerState)
    ahu.OutdoorAirTempC = 16.0
    ahu.ReturnAirTempC = 23.5
    ahu.MixedAirTempC = 20.0
    ahu.SupplyAirTempC = 13.5
    ahu.SupplyAirTempSP = 13.5
    
    ahu.OutdoorDamperOP = 20.0     ' 20% minimum outdoor air ventilation
    ahu.ReturnDamperOP = 80.0
    ahu.CoolingCoilValveOP = 35.0
    ahu.HeatingCoilValveOP = 0.0
    ahu.SupplyFanSpeedHz = 48.0
    
    ahu.SupplyAirFlowCFM = 18500.0
    ahu.DuctStaticPressInWg = 1.25
    ahu.StaticPressSPInWg = 1.25
    ahu.IndoorCo2Ppm = 620.0
    
    ahu.EconomizerActive = 0
    ahu.FreezeStatTripped = 0
END SUB

' StepAhuControlCycle: Executes one supervisory cycle (nominal dt = 1.0 sec)
SUB StepAhuControlCycle(ahu AS AhuControllerState, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    ' 1. Freeze Protection Interlock (Hard safety trip)
    IF ahu.MixedAirTempC < 3.5 THEN
        ahu.FreezeStatTripped = 1
        ahu.SupplyFanSpeedHz = 0.0
        ahu.OutdoorDamperOP = 0.0
        ahu.HeatingCoilValveOP = 100.0 ' Full open heating coil to prevent burst tubes
        PRINT "[FREEZE STAT TRIP] Low Mixed Air Temp:"; ahu.MixedAirTempC; "deg C. Fan Stopped!"
        EXIT SUB
    END IF
    
    ' 2. ASHRAE Guideline 36 SAT Reset Schedule:
    ' When OAT <= 10 deg C -> SAT_SP = 18.0 deg C (Warm supply air)
    ' When OAT >= 22 deg C -> SAT_SP = 13.0 deg C (Max cooling)
    ' Linear ramp in between [10, 22] deg C
    IF ahu.OutdoorAirTempC <= 10.0 THEN
        ahu.SupplyAirTempSP = 18.0
    ELSEIF ahu.OutdoorAirTempC >= 22.0 THEN
        ahu.SupplyAirTempSP = 13.0
    ELSE
        DIM frac AS DOUBLE : frac = (ahu.OutdoorAirTempC - 10.0) / 12.0
        ahu.SupplyAirTempSP = 18.0 - frac * 5.0
    END IF
    
    ' 3. Free Cooling Economizer Damper Logic
    ' Economizer enabled if OAT < (RAT - 1.5 C) and OAT > 11.0 C
    IF ahu.OutdoorAirTempC < (ahu.ReturnAirTempC - 1.5) AND ahu.OutdoorAirTempC > 11.0 THEN
        ahu.EconomizerActive = 1
        ' Modulate damper to satisfy SAT_SP without mechanical cooling
        DIM econDemand AS DOUBLE : econDemand = (ahu.ReturnAirTempC - ahu.SupplyAirTempSP) / (ahu.ReturnAirTempC - ahu.OutdoorAirTempC) * 100.0
        ahu.OutdoorDamperOP = ClampValue(econDemand, 20.0, 100.0)
    ELSE
        ahu.EconomizerActive = 0
        ' Demand controlled ventilation: increase outdoor air if CO2 > 800 ppm
        IF ahu.IndoorCo2Ppm > 800.0 THEN
            ahu.OutdoorDamperOP = ClampValue(20.0 + (ahu.IndoorCo2Ppm - 800.0) * 0.1, 20.0, 60.0)
        ELSE
            ahu.OutdoorDamperOP = 20.0 ' Minimum ventilation base
        END IF
    END IF
    ahu.ReturnDamperOP = 100.0 - ahu.OutdoorDamperOP
    
    ' 4. Mixed Air Temperature Adiabatic Balance
    DIM oaFrac AS DOUBLE : oaFrac = ahu.OutdoorDamperOP / 100.0
    ahu.MixedAirTempC = oaFrac * ahu.OutdoorAirTempC + (1.0 - oaFrac) * ahu.ReturnAirTempC
    
    ' 5. Cooling & Heating Coil PID Sequencing
    DIM satError AS DOUBLE : satError = ahu.SupplyAirTempC - ahu.SupplyAirTempSP
    IF satError > 0.2 THEN
        ' Warm: open cooling coil, close heating coil
        ahu.CoolingCoilValveOP = ClampValue(ahu.CoolingCoilValveOP + 1.2 * satError * dtSec, 0.0, 100.0)
        ahu.HeatingCoilValveOP = 0.0
    ELSEIF satError < -0.2 THEN
        ' Cold: open heating coil, close cooling coil
        ahu.HeatingCoilValveOP = ClampValue(ahu.HeatingCoilValveOP - 1.2 * satError * dtSec, 0.0, 100.0)
        ahu.CoolingCoilValveOP = 0.0
    END IF
    
    ' 6. Simulated Supply Air Temperature Response
    DIM netCoilDutyC AS DOUBLE
    netCoilDutyC = (ahu.HeatingCoilValveOP * 0.15) - (ahu.CoolingCoilValveOP * 0.12)
    ahu.SupplyAirTempC = ahu.SupplyAirTempC + ((ahu.MixedAirTempC + netCoilDutyC - ahu.SupplyAirTempC) / 15.0) * dtSec
END SUB
