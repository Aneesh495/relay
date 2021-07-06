' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Combined-Cycle Power Plant HRSG Coordinated Boiler-Turbine Controller
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/app/power_plant_app.bas
' ==============================================================================
'
' This application implements supervisory power generation control for a
' combined-cycle power block (Gas Turbine + Heat Recovery Steam Generator + Steam Turbine):
'   - Three-element drum level control (Level + Steam Flow + Feedwater Flow)
'   - High-Pressure superheater steam temperature spray attemperation
'   - High-Pressure turbine bypass station to condenser on turbine trip
'   - Generator active power (Megawatts) and grid frequency droop regulation
'   - Black-plant start-up sequence and thermal stress ramp rate limiting
' ==============================================================================

TYPE PowerPlantState
    ' Gas Turbine (GT) Flue Gas Source
    GtLoadMW           AS DOUBLE  ' Gas turbine electrical generation (0 to 180 MW)
    ExhaustFlueTempC   AS DOUBLE  ' HRSG inlet exhaust temperature (580.0 deg C)
    FlueGasFlowKgS     AS DOUBLE  ' Flue gas mass flow entering boiler (450.0 kg/s)
    
    ' High-Pressure (HP) Drum & Steam Loop
    HpDrumPressureBar  AS DOUBLE  ' High pressure drum (110.0 bar)
    HpDrumLevelMm      AS DOUBLE  ' Level deviation (-500 to +500 mm relative to center)
    HpSteamFlowKgS     AS DOUBLE  ' Generated HP steam flow (68.0 kg/s)
    HpFeedwaterFlowKgS AS DOUBLE  ' High-pressure feedwater inflow
    HpSuperheatTempC   AS DOUBLE  ' Live steam temperature (565.0 deg C)
    
    ' Steam Turbine (ST) & Generator
    StLoadMW           AS DOUBLE  ' Steam turbine electrical generation (0 to 95 MW)
    TotalPlantMW       AS DOUBLE  ' GT MW + ST MW
    GridFrequencyHz    AS DOUBLE  ' Electrical grid frequency (50.00 Hz)
    
    ' Actuator Outputs
    FeedwaterControlValveOP AS DOUBLE ' 3-element valve position (0 to 100%)
    AttemperatorSprayValveOP AS DOUBLE' Desuperheater spray valve
    HpTurbineBypassValveOP  AS DOUBLE ' Dump to steam condenser
    GovernorValveOP         AS DOUBLE ' Steam turbine throttle valve
    
    ' Trip and Status Flags
    SteamTurbineTripped     AS INTEGER
    CondenserVacuumBar      AS DOUBLE ' -0.92 bar (deep vacuum)
END TYPE

' InitializePowerPlant: Sets up 275 MW Combined Cycle Block
SUB InitializePowerPlant(pp AS PowerPlantState)
    pp.GtLoadMW = 165.0
    pp.ExhaustFlueTempC = 582.0
    pp.FlueGasFlowKgS = 460.0
    
    pp.HpDrumPressureBar = 108.5
    pp.HpDrumLevelMm = 0.0        ' Centered on zero
    pp.HpSteamFlowKgS = 65.0
    pp.HpFeedwaterFlowKgS = 65.0
    pp.HpSuperheatTempC = 565.0
    
    pp.StLoadMW = 88.0
    pp.TotalPlantMW = 253.0
    pp.GridFrequencyHz = 50.00
    
    pp.FeedwaterControlValveOP = 65.0
    pp.AttemperatorSprayValveOP = 14.0
    pp.HpTurbineBypassValveOP = 0.0
    pp.GovernorValveOP = 82.0
    
    pp.SteamTurbineTripped = 0
    pp.CondenserVacuumBar = -0.94
END SUB

' ExecutePowerPlantControlCycle: Runs one supervisory cycle
SUB ExecutePowerPlantControlCycle(pp AS PowerPlantState, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    ' 1. Steam Turbine Fast Trip Protection
    IF pp.HpDrumLevelMm > 250.0 OR pp.CondenserVacuumBar > -0.60 THEN
        pp.SteamTurbineTripped = 1
        pp.GovernorValveOP = 0.0
        pp.HpTurbineBypassValveOP = 100.0 ' Fast open bypass to protect boiler
        pp.StLoadMW = 0.0
        PRINT "[TURBINE TRIP] Steam Turbine Tripped! HP Bypass Fast Opened 100%!"
    END IF
    
    ' 2. Three-Element Drum Level Control:
    ' Output = Level_PID(LevelErr) + (SteamFlow - FeedwaterFlow) feedforward
    DIM levelErrorMm AS DOUBLE : levelErrorMm = 0.0 - pp.HpDrumLevelMm
    DIM flowDiscrepancyKgS AS DOUBLE : flowDiscrepancyKgS = pp.HpSteamFlowKgS - pp.HpFeedwaterFlowKgS
    
    DIM deltaFcvOP AS DOUBLE
    deltaFcvOP = (0.05 * levelErrorMm + 0.4 * flowDiscrepancyKgS) * dtSec
    pp.FeedwaterControlValveOP = ClampValue(pp.FeedwaterControlValveOP + deltaFcvOP, 0.0, 100.0)
    pp.HpFeedwaterFlowKgS = (pp.FeedwaterControlValveOP / 100.0) * 100.0
    
    ' 3. Superheater Temperature Attemperation Control
    DIM tempErrorC AS DOUBLE : tempErrorC = pp.HpSuperheatTempC - 565.0
    DIM deltaSprayOP AS DOUBLE : deltaSprayOP = 0.6 * tempErrorC * dtSec
    pp.AttemperatorSprayValveOP = ClampValue(pp.AttemperatorSprayValveOP + deltaSprayOP, 0.0, 100.0)
    
    ' 4. Primary Grid Frequency Droop Response (4% droop regulation)
    DIM freqDeltaHz AS DOUBLE : freqDeltaHz = 50.00 - pp.GridFrequencyHz
    DIM droopCompensationMW AS DOUBLE : droopCompensationMW = (freqDeltaHz / 50.00) * (1.0 / 0.04) * pp.GtLoadMW
    pp.GtLoadMW = ClampValue(pp.GtLoadMW + droopCompensationMW * dtSec, 50.0, 180.0)
    
    ' 5. Aggregate Plant Power
    IF pp.SteamTurbineTripped = 0 THEN
        pp.StLoadMW = (pp.GovernorValveOP / 100.0) * 95.0
    ELSE
        pp.StLoadMW = 0.0
    END IF
    pp.TotalPlantMW = pp.GtLoadMW + pp.StLoadMW
    
    ' Physical response simulation
    pp.HpDrumLevelMm = pp.HpDrumLevelMm + (pp.HpFeedwaterFlowKgS - pp.HpSteamFlowKgS) * 0.2 * dtSec
    pp.HpSuperheatTempC = pp.HpSuperheatTempC - (pp.AttemperatorSprayValveOP - 14.0) * 0.1 * dtSec
END SUB
