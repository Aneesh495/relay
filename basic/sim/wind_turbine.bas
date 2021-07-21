' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Utility-Scale 3.5 MW Variable-Speed Wind Turbine Digital Twin Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/wind_turbine.bas
' ==============================================================================
'
' This module implements the aeroelastic, mechanical, and electrical dynamics
' of an industrial 3.5 MW pitch-regulated horizontal-axis wind turbine:
'   - Betz aerodynamic power extraction: P = 0.5 * rho * A * v^3 * Cp(lambda, beta)
'   - Tip-Speed Ratio (TSR) lambda = (omega * R) / v
'   - Non-linear Heier Cp(lambda, beta) aerodynamic power coefficient surface
'   - Region 2 Maximum Power Point Tracking (MPPT) optimal torque control
'   - Region 3 Active collective blade pitch regulation (0 to 90 deg)
'   - Two-mass drive train model with low-speed and high-speed shaft torsion
' ==============================================================================

CONST AIR_DENSITY = 1.225    ' kg / m^3 at sea level
CONST ROTOR_RADIUS = 56.0    ' meters (112 m rotor diameter)
CONST SWEPT_AREA = 9852.0    ' m^2 (pi * R^2)
CONST GEARBOX_RATIO = 95.0   ' 1:95 speed multiplier

TYPE WindTurbineState
    ' Wind Resource
    WindSpeedMS     AS DOUBLE  ' Instantaneous hub-height wind speed (m/s)
    WindDirectionDeg AS DOUBLE ' Meteorological wind heading
    NacelleYawDeg   AS DOUBLE  ' Nacelle pointing heading
    YawErrorDeg     AS DOUBLE  ' Tracking misalignment
    
    ' Aerodynamics
    BladePitchDeg   AS DOUBLE  ' Collective pitch angle beta (0 = Power, 90 = Feathered)
    BladePitchSP    AS DOUBLE  ' Pitch actuator setpoint
    TipSpeedRatio   AS DOUBLE  ' TSR lambda
    PowerCoeffCp    AS DOUBLE  ' Aerodynamic efficiency Cp [0, 0.50]
    AeroTorqueKNm   AS DOUBLE  ' Aerodynamic rotor torque Qa
    
    ' Drive Train Mechanics
    RotorSpeedRpm   AS DOUBLE  ' Low-speed shaft speed (nominal 12.0 RPM)
    GenSpeedRpm     AS DOUBLE  ' High-speed generator shaft speed (nominal 1140.0 RPM)
    RotorInertia    AS DOUBLE  ' Rotor moment of inertia (kg * m^2)
    ShaftTorsionRad AS DOUBLE  ' Drive-train torsional twist angle
    
    ' Electrical Generation
    ElectricalPowerKW AS DOUBLE' Active electrical power exported to grid
    GeneratorTorqueKNm AS DOUBLE' Generator electromagnetic braking torque
    GridConnected   AS INTEGER ' 1 = Synchronized to AC collector substation
    TurbineState    AS INTEGER ' 1=Stop, 2=Start, 3=MPPT (Reg 2), 4=Pitch (Reg 3)
END TYPE

' InitializeWindTurbine: Configures 3.5 MW direct/geared turbine
SUB InitializeWindTurbine(wt AS WindTurbineState)
    wt.WindSpeedMS = 9.5
    wt.WindDirectionDeg = 270.0
    wt.NacelleYawDeg = 270.0
    wt.YawErrorDeg = 0.0
    
    wt.BladePitchDeg = 0.0
    wt.BladePitchSP = 0.0
    wt.TipSpeedRatio = 7.5
    wt.PowerCoeffCp = 0.44
    wt.AeroTorqueKNm = 1850.0
    
    wt.RotorSpeedRpm = 12.2
    wt.GenSpeedRpm = 1159.0
    wt.RotorInertia = 4.5E6
    wt.ShaftTorsionRad = 0.015
    
    wt.ElectricalPowerKW = 2350.0
    wt.GeneratorTorqueKNm = 19.5
    wt.GridConnected = 1
    wt.TurbineState = 3        ' Region 2 MPPT
END SUB

' ComputeCp: Calculates Heier aerodynamic power coefficient Cp(lambda, beta)
FUNCTION ComputeCp(lambdaVal AS DOUBLE, betaVal AS DOUBLE) AS DOUBLE
    IF lambdaVal <= 0.5 THEN
        ComputeCp = 0.0
        EXIT FUNCTION
    END IF
    
    ' 1 / lambda_i = 1 / (lambda + 0.08 * beta) - 0.035 / (beta^3 + 1)
    DIM term1 AS DOUBLE : term1 = 1.0 / (lambdaVal + 0.08 * betaVal)
    DIM term2 AS DOUBLE : term2 = 0.035 / (betaVal * betaVal * betaVal + 1.0)
    DIM invLambdaI AS DOUBLE : invLambdaI = term1 - term2
    
    IF invLambdaI <= 0.0 THEN
        ComputeCp = 0.0
        EXIT FUNCTION
    END IF
    
    ' Cp = c1 * (c2 * invLambdaI - c3 * beta - c4) * exp(-c5 * invLambdaI) + c6 * lambda
    DIM bracket AS DOUBLE : bracket = 116.0 * invLambdaI - 0.4 * betaVal - 5.0
    DIM cpRaw AS DOUBLE : cpRaw = 0.5176 * bracket * EXP(-21.0 * invLambdaI) + 0.0068 * lambdaVal
    
    IF cpRaw < 0.0 THEN cpRaw = 0.0
    IF cpRaw > 0.48 THEN cpRaw = 0.48 ' Physical limit
    ComputeCp = cpRaw
END FUNCTION

' StepWindTurbineEuler: Simulates aeroelastic and pitch control dynamics
SUB StepWindTurbineEuler(wt AS WindTurbineState, windSpeedMS AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    wt.WindSpeedMS = ClampValue(windSpeedMS, 0.0, 40.0)
    
    ' 1. Cut-In / Cut-Out Operational Window Supervision
    IF wt.WindSpeedMS < 3.0 OR wt.WindSpeedMS > 25.0 THEN
        ' Feather blades and stop turbine
        wt.TurbineState = 1 ' Stopped
        wt.BladePitchSP = 90.0
        wt.GridConnected = 0
        wt.ElectricalPowerKW = 0.0
    ELSE
        wt.GridConnected = 1
    END IF
    
    ' 2. Pitch Actuator Slew Rate Limiter (Max 8 deg/sec)
    DIM pitchDiff AS DOUBLE : pitchDiff = wt.BladePitchSP - wt.BladePitchDeg
    DIM maxPitchStep AS DOUBLE : maxPitchStep = 8.0 * dtSec
    IF pitchDiff > maxPitchStep THEN pitchDiff = maxPitchStep
    IF pitchDiff < -maxPitchStep THEN pitchDiff = -maxPitchStep
    wt.BladePitchDeg = ClampValue(wt.BladePitchDeg + pitchDiff, 0.0, 90.0)
    
    ' 3. Aerodynamics: Tip-Speed Ratio and Cp
    DIM omegaRotorRadS AS DOUBLE : omegaRotorRadS = (wt.RotorSpeedRpm * 2.0 * 3.14159) / 60.0
    IF wt.WindSpeedMS > 0.1 THEN
        wt.TipSpeedRatio = (omegaRotorRadS * ROTOR_RADIUS) / wt.WindSpeedMS
    ELSE
        wt.TipSpeedRatio = 0.0
    END IF
    
    wt.PowerCoeffCp = ComputeCp(wt.TipSpeedRatio, wt.BladePitchDeg)
    
    ' Available wind power: P_avail = 0.5 * rho * A * v^3
    DIM pAvailWatts AS DOUBLE
    pAvailWatts = 0.5 * AIR_DENSITY * SWEPT_AREA * wt.WindSpeedMS * wt.WindSpeedMS * wt.WindSpeedMS
    DIM aeroPowerWatts AS DOUBLE : aeroPowerWatts = pAvailWatts * wt.PowerCoeffCp
    
    IF omegaRotorRadS > 0.05 THEN
        wt.AeroTorqueKNm = (aeroPowerWatts / omegaRotorRadS) / 1000.0
    ELSE
        wt.AeroTorqueKNm = 0.0
    END IF
    
    ' 4. Supervisory Control Logic: Region 2 vs Region 3
    IF wt.WindSpeedMS <= 11.5 AND wt.TurbineState <> 1 THEN
        ' Region 2: MPPT mode (Blade pitch fixed at optimal 0 deg, control generator torque)
        wt.TurbineState = 3
        wt.BladePitchSP = 0.0
        ' Optimal torque law: T_gen = k_opt * omega^2
        wt.GeneratorTorqueKNm = 0.014 * wt.RotorSpeedRpm * wt.RotorSpeedRpm
    ELSEIF wt.WindSpeedMS > 11.5 AND wt.TurbineState <> 1 THEN
        ' Region 3: Rated power pitch control mode
        wt.TurbineState = 4
        ' Pitch controller regulates generator speed to rated 1200 RPM
        DIM speedErrorRpm AS DOUBLE : speedErrorRpm = wt.GenSpeedRpm - 1200.0
        wt.BladePitchSP = ClampValue(wt.BladePitchSP + 0.15 * speedErrorRpm * dtSec, 0.0, 35.0)
        wt.GeneratorTorqueKNm = 28.5 ' Rated torque
    END IF
    
    ' 5. Rotor Acceleration Dynamics (J * d_omega/dt = T_aero - N * T_gen)
    DIM netRotorTorqueKNm AS DOUBLE
    netRotorTorqueKNm = wt.AeroTorqueKNm - (wt.GeneratorTorqueKNm * GEARBOX_RATIO * 0.97) ' 97% gearbox efficiency
    
    DIM dOmegaDt AS DOUBLE : dOmegaDt = (netRotorTorqueKNm * 1000.0) / wt.RotorInertia
    omegaRotorRadS = omegaRotorRadS + dOmegaDt * dtSec
    IF omegaRotorRadS < 0.0 THEN omegaRotorRadS = 0.0
    
    wt.RotorSpeedRpm = (omegaRotorRadS * 60.0) / (2.0 * 3.14159)
    wt.GenSpeedRpm = wt.RotorSpeedRpm * GEARBOX_RATIO
    
    ' 6. Exported Electrical Power: P = T_gen * omega_gen * eff_gen
    DIM omegaGenRadS AS DOUBLE : omegaGenRadS = (wt.GenSpeedRpm * 2.0 * 3.14159) / 60.0
    IF wt.GridConnected = 1 THEN
        wt.ElectricalPowerKW = wt.GeneratorTorqueKNm * omegaGenRadS * 0.95 ' 95% generator efficiency
        IF wt.ElectricalPowerKW > 3500.0 THEN wt.ElectricalPowerKW = 3500.0 ' Rated 3.5 MW ceiling
    ELSE
        wt.ElectricalPowerKW = 0.0
    END IF
END SUB
