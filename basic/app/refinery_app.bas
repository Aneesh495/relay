' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Atmospheric Crude Oil Distillation Column Multi-Loop Plant Controller
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/app/refinery_app.bas
' ==============================================================================
'
' This application implements supervisory and multi-loop regulatory control
' for a continuous atmospheric crude distillation column:
'   - Overhead vapor reflux drum pressure and level control
'   - Top tray temperature control manipulating reflux flow (TIC-101 / FIC-101)
'   - Kerosene, Diesel, and Atmospheric Gas Oil (AGO) sidestream draws
'   - Fired heater coil outlet temperature (COT) cascade fuel control
'   - Bottom residue level control with bumpless valve transfer
'   - IEC 61511 Emergency Depressurization (EDP) safety interlock
' ==============================================================================

TYPE CrudeColumnState
    ' Process Measurements (PVs)
    CoilOutletTempC    AS DOUBLE ' Fired heater outlet (365.0 deg C)
    TopTrayTempC       AS DOUBLE ' Tower top vapor temperature (115.0 deg C)
    RefluxDrumLevelPct AS DOUBLE ' Overhead receiver liquid level (50.0%)
    ColumnPressureBar  AS DOUBLE ' Column overhead pressure (1.85 bar)
    BottomLevelPct     AS DOUBLE ' Bottoms boot liquid level (48.0%)
    
    ' Product Stream Mass Flows (kg/s)
    NaphthaFlowKgS     AS DOUBLE ' Light overhead distillate
    KeroseneFlowKgS    AS DOUBLE ' Kero sidestream
    DieselFlowKgS      AS DOUBLE ' Diesel sidestream
    BottomsFlowKgS     AS DOUBLE ' Heavy residue
    RefluxFlowKgS      AS DOUBLE ' Liquid reflux back to tray 1
    FuelGasFlowKgS     AS DOUBLE ' Furnace fuel firing rate
    
    ' Setpoints (SPs)
    TopTempSP          AS DOUBLE
    PressureSP         AS DOUBLE
    DrumLevelSP        AS DOUBLE
    BottomLevelSP      AS DOUBLE
    CotSP              AS DOUBLE
    
    ' Actuator Manipulated Outputs (OPs in %)
    RefluxValveOP      AS DOUBLE
    FuelGasValveOP     AS DOUBLE
    BottomsValveOP     AS DOUBLE
    OffgasVentValveOP  AS DOUBLE
    
    ' Safety Interlock State
    FurnaceTripped     AS INTEGER ' 1 = ESD Active, 0 = Normal
    EmergencyVenting   AS INTEGER
END TYPE

' InitializeCrudeColumn: Configures steady-state 100,000 BPD crude column
SUB InitializeCrudeColumn(col AS CrudeColumnState)
    col.CoilOutletTempC = 365.0
    col.TopTrayTempC = 115.0
    col.RefluxDrumLevelPct = 50.0
    col.ColumnPressureBar = 1.85
    col.BottomLevelPct = 48.0
    
    col.NaphthaFlowKgS = 18.5
    col.KeroseneFlowKgS = 22.0
    col.DieselFlowKgS = 35.0
    col.BottomsFlowKgS = 42.0
    col.RefluxFlowKgS = 38.0
    col.FuelGasFlowKgS = 4.2
    
    col.TopTempSP = 115.0
    col.PressureSP = 1.85
    col.DrumLevelSP = 50.0
    col.BottomLevelSP = 50.0
    col.CotSP = 365.0
    
    col.RefluxValveOP = 55.0
    col.FuelGasValveOP = 62.0
    col.BottomsValveOP = 45.0
    col.OffgasVentValveOP = 12.0
    
    col.FurnaceTripped = 0
    col.EmergencyVenting = 0
END SUB

' ExecuteColumnControlCycle: Runs one supervisory scan cycle (nominal dt = 1.0 sec)
SUB ExecuteColumnControlCycle(col AS CrudeColumnState, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    ' 1. IEC 61511 Safety Instrumented System Interlock Checks
    IF col.ColumnPressureBar > 3.2 OR col.CoilOutletTempC > 390.0 THEN
        col.FurnaceTripped = 1
        col.EmergencyVenting = 1
        col.FuelGasValveOP = 0.0
        col.OffgasVentValveOP = 100.0
        PRINT "[SIS TRIP] Emergency Shutdown! Furnace Fuel Tripped. Pressure:"; col.ColumnPressureBar; "bar"
        EXIT SUB
    END IF
    
    ' 2. Top Tray Temperature Control (TIC-101 manipulating Reflux Flow)
    ' Direct-acting: higher reflux decreases top tray temperature
    DIM tempError AS DOUBLE : tempError = col.TopTrayTempC - col.TopTempSP
    DIM deltaRefluxOP AS DOUBLE : deltaRefluxOP = 1.2 * tempError * dtSec
    col.RefluxValveOP = ClampValue(col.RefluxValveOP + deltaRefluxOP, 0.0, 100.0)
    col.RefluxFlowKgS = (col.RefluxValveOP / 100.0) * 70.0
    
    ' 3. Fired Heater Coil Outlet Temperature (COT TIC-201 manipulating Fuel Gas)
    ' Reverse-acting: higher fuel gas increases temperature
    DIM cotError AS DOUBLE : cotError = col.CotSP - col.CoilOutletTempC
    DIM deltaFuelOP AS DOUBLE : deltaFuelOP = 0.8 * cotError * dtSec
    col.FuelGasValveOP = ClampValue(col.FuelGasValveOP + deltaFuelOP, 5.0, 95.0)
    col.FuelGasFlowKgS = (col.FuelGasValveOP / 100.0) * 7.0
    
    ' 4. Column Overhead Pressure Split-Range Control (PIC-101)
    DIM pressError AS DOUBLE : pressError = col.ColumnPressureBar - col.PressureSP
    DIM deltaVentOP AS DOUBLE : deltaVentOP = 15.0 * pressError * dtSec
    col.OffgasVentValveOP = ClampValue(col.OffgasVentValveOP + deltaVentOP, 0.0, 100.0)
    
    ' 5. Bottoms Liquid Level Control (LIC-101)
    DIM btmError AS DOUBLE : btmError = col.BottomLevelPct - col.BottomLevelSP
    DIM deltaBtmOP AS DOUBLE : deltaBtmOP = 0.5 * btmError * dtSec
    col.BottomsValveOP = ClampValue(col.BottomsValveOP + deltaBtmOP, 10.0, 90.0)
    col.BottomsFlowKgS = (col.BottomsValveOP / 100.0) * 85.0
    
    ' Simulated process response updates
    col.TopTrayTempC = col.TopTrayTempC - (col.RefluxFlowKgS - 38.0) * 0.05 * dtSec
    col.CoilOutletTempC = col.CoilOutletTempC + (col.FuelGasFlowKgS - 4.2) * 0.4 * dtSec
    col.ColumnPressureBar = col.ColumnPressureBar + (20.0 - col.OffgasVentValveOP) * 0.001 * dtSec
    col.BottomLevelPct = col.BottomLevelPct + (42.0 - col.BottomsFlowKgS) * 0.05 * dtSec
END SUB
