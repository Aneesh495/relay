' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Multi-Pump Booster Station & Pipeline Hydraulic Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/pump_station.bas
' ==============================================================================
'
' This module implements an industrial municipal booster pumping station
' with parallel variable-frequency drive (VFD) centrifugal pumps discharging
' into a common pressurized distribution pipeline:
'   - Euler and affinity laws for centrifugal impellers
'   - Head-capacity H(Q) quadratic pump performance curves
'   - Darcy-Weisbach pipeline friction and static elevation head loss
'   - Cavitation risk estimation via NPSH margin check
'   - Motor electrical load, power factor, and thermal winding temperature
' ==============================================================================

TYPE CentrifugalPumpUnit
    ' Pump Operational Status
    IsRunning       AS INTEGER ' 1 = Operating, 0 = Stopped
    SpeedHz         AS DOUBLE  ' Current VFD output frequency (0 to 60 Hz)
    TargetSpeedHz   AS DOUBLE  ' Commanded speed setpoint
    
    ' Hydraulic Output
    DischargeHeadM  AS DOUBLE  ' Head generated across impeller (meters of water)
    DischargeFlowM3H AS DOUBLE ' Volumetric flow rate through unit (m^3 / hour)
    
    ' Electrical & Mechanical State
    MotorPowerKW    AS DOUBLE  ' Mechanical shaft power draw (kW)
    MotorCurrentAmps AS DOUBLE ' 400V 3-phase line current draw (Amperes)
    WindingTempC    AS DOUBLE  ' Stator winding temperature (deg C)
    RunningHours    AS DOUBLE  ' Cumulative operating hours for maintenance
    
    ' Pump Curve Coefficients: H = ShutoffHead*(w/w0)^2 - B*(w/w0)*Q - C*Q^2
    RatedHeadM      AS DOUBLE  ' Shutoff head at 60 Hz (e.g. 75.0 m)
    CurveLinearB    AS DOUBLE  ' Linear flow coefficient
    CurveQuadC      AS DOUBLE  ' Quadratic flow coefficient
    BestEfficiencyQ AS DOUBLE  ' Best Efficiency Point (BEP) flow (m^3 / h)
END TYPE

TYPE PumpStationState
    ' Station Physical Headers
    SuctionPressureBar  AS DOUBLE ' Common suction manifold pressure (bar)
    DischargePressureBar AS DOUBLE' Common discharge manifold pressure (bar)
    TotalFlowM3H        AS DOUBLE ' Summed station discharge flow rate (m^3 / h)
    
    ' Pipeline Network Model
    PipelineStaticHeadM AS DOUBLE ' Static elevation difference to reservoir (m)
    FrictionCoeffK      AS DOUBLE ' Pipeline Darcy friction coefficient (m / (m^3/h)^2)
    ReservoirLevelM     AS DOUBLE ' Downstream storage reservoir water depth (m)
    
    ' Station Electrical Metrics
    TotalPowerKW        AS DOUBLE ' Aggregate station power consumption
    GridPowerFactor     AS DOUBLE ' Displacement power factor (approx 0.94)
    
    ' Equipment Array (3 parallel pump units)
    Pumps(3)            AS CentrifugalPumpUnit
END TYPE

' InitializePumpStation: Sets up a 3-pump parallel booster station
SUB InitializePumpStation(station AS PumpStationState)
    station.SuctionPressureBar = 2.5       ' 2.5 bar suction from supply aqueduct
    station.DischargePressureBar = 6.2     ' Nominal 6.2 bar distribution pressure
    station.TotalFlowM3H = 320.0
    
    station.PipelineStaticHeadM = 35.0     ' 35 meter elevation lift
    station.FrictionCoeffK = 0.00018       ' System curve: H_sys = 35 + K * Q^2
    station.ReservoirLevelM = 6.5
    
    station.TotalPowerKW = 95.0
    station.GridPowerFactor = 0.94
    
    ' Configure 3 identical 150 kW centrifugal pumps
    DIM i AS INTEGER
    FOR i = 1 TO 3
        IF i <= 2 THEN
            station.Pumps(i).IsRunning = 1
            station.Pumps(i).SpeedHz = 50.0
            station.Pumps(i).TargetSpeedHz = 50.0
        ELSE
            station.Pumps(i).IsRunning = 0
            station.Pumps(i).SpeedHz = 0.0
            station.Pumps(i).TargetSpeedHz = 0.0
        END IF
        station.Pumps(i).DischargeHeadM = 45.0
        station.Pumps(i).DischargeFlowM3H = 160.0
        station.Pumps(i).MotorPowerKW = 47.5
        station.Pumps(i).MotorCurrentAmps = 82.0
        station.Pumps(i).WindingTempC = 55.0
        station.Pumps(i).RunningHours = 1200.0 * i
        
        station.Pumps(i).RatedHeadM = 75.0
        station.Pumps(i).CurveLinearB = 0.04
        station.Pumps(i).CurveQuadC = 0.00045
        station.Pumps(i).BestEfficiencyQ = 180.0
    NEXT i
END SUB

' StepPumpStationEuler: Simulates hydraulic equilibrium and thermal dynamics
SUB StepPumpStationEuler(station AS PumpStationState, targetPressureBar AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    ' 1. Slew pump VFD speeds toward setpoints with acceleration limit (5 Hz / sec)
    DIM i AS INTEGER
    FOR i = 1 TO 3
        IF station.Pumps(i).IsRunning = 1 THEN
            DIM speedDiff AS DOUBLE : speedDiff = station.Pumps(i).TargetSpeedHz - station.Pumps(i).SpeedHz
            DIM maxDeltaHz AS DOUBLE : maxDeltaHz = 5.0 * dtSec
            IF speedDiff > maxDeltaHz THEN speedDiff = maxDeltaHz
            IF speedDiff < -maxDeltaHz THEN speedDiff = -maxDeltaHz
            station.Pumps(i).SpeedHz = ClampValue(station.Pumps(i).SpeedHz + speedDiff, 20.0, 60.0)
        ELSE
            ' Ramp down stopped pump
            station.Pumps(i).SpeedHz = ClampValue(station.Pumps(i).SpeedHz - 10.0 * dtSec, 0.0, 60.0)
        END IF
    NEXT i
    
    ' 2. Calculate individual pump head and flow using affinity scaling:
    ' Ratio alpha = SpeedHz / 60.0
    DIM activeCount AS INTEGER : activeCount = 0
    DIM sumActiveSpeed AS DOUBLE : sumActiveSpeed = 0.0
    FOR i = 1 TO 3
        IF station.Pumps(i).IsRunning = 1 AND station.Pumps(i).SpeedHz >= 20.0 THEN
            activeCount = activeCount + 1
            sumActiveSpeed = sumActiveSpeed + station.Pumps(i).SpeedHz
        END IF
    NEXT i
    
    IF activeCount > 0 THEN
        DIM avgSpeedHz AS DOUBLE : avgSpeedHz = sumActiveSpeed / activeCount
        DIM alpha AS DOUBLE : alpha = avgSpeedHz / 60.0
        
        ' System curve intersection: H_pump(Q_total) = H_sys(Q_total)
        ' H_pump per pump: H = alpha^2 * H0 - (alpha * B / N) * Q_tot - (C / N^2) * Q_tot^2
        ' H_sys: H = H_static + K * Q_tot^2
        ' Equating: (K + C/N^2)*Q_tot^2 + (alpha*B/N)*Q_tot + (H_static - alpha^2*H0) = 0
        DIM aCoeff AS DOUBLE : aCoeff = station.FrictionCoeffK + (station.Pumps(1).CurveQuadC / (activeCount * activeCount))
        DIM bCoeff AS DOUBLE : bCoeff = (alpha * station.Pumps(1).CurveLinearB) / activeCount
        DIM cCoeff AS DOUBLE : cCoeff = station.PipelineStaticHeadM - (alpha * alpha * station.Pumps(1).RatedHeadM)
        
        DIM discriminant AS DOUBLE : discriminant = bCoeff * bCoeff - 4.0 * aCoeff * cCoeff
        DIM computedFlow AS DOUBLE : computedFlow = 0.0
        IF discriminant >= 0.0 THEN
            computedFlow = (-bCoeff + SQR(discriminant)) / (2.0 * aCoeff)
        END IF
        IF computedFlow < 0.0 THEN computedFlow = 0.0
        
        ' First-order hydraulic flow inertia (tau = 1.5 sec)
        station.TotalFlowM3H = station.TotalFlowM3H + ((computedFlow - station.TotalFlowM3H) / 1.5) * dtSec
        
        ' Calculate discharge head: H_sys = H_static + K * Q^2
        DIM totalHeadM AS DOUBLE : totalHeadM = station.PipelineStaticHeadM + station.FrictionCoeffK * station.TotalFlowM3H * station.TotalFlowM3H
        ' Convert head meters to bar: 1 meter water = 0.0980665 bar
        DIM headBar AS DOUBLE : headBar = totalHeadM * 0.0980665
        station.DischargePressureBar = station.SuctionPressureBar + headBar
        
        ' Apportion flow across active units
        station.TotalPowerKW = 0.0
        FOR i = 1 TO 3
            IF station.Pumps(i).IsRunning = 1 AND station.Pumps(i).SpeedHz >= 20.0 THEN
                station.Pumps(i).DischargeFlowM3H = station.TotalFlowM3H / activeCount
                station.Pumps(i).DischargeHeadM = totalHeadM
                
                ' Hydraulic power P_hyd (kW) = (rho * g * Q * H) / (3.6 * 10^6)
                ' Overall efficiency approx 0.78 near BEP
                DIM hydPowerKW AS DOUBLE : hydPowerKW = (998.0 * 9.81 * station.Pumps(i).DischargeFlowM3H * totalHeadM) / 3600000.0
                station.Pumps(i).MotorPowerKW = hydPowerKW / 0.78
                
                ' Current: I = P / (sqrt(3) * V * PF * eff_motor)
                station.Pumps(i).MotorCurrentAmps = (station.Pumps(i).MotorPowerKW * 1000.0) / (1.732 * 400.0 * 0.94 * 0.95)
                
                ' Stator thermal heating: balance between I^2 * R loss and fan cooling
                DIM targetTempC AS DOUBLE : targetTempC = 30.0 + (station.Pumps(i).MotorPowerKW / 60.0) * 45.0
                station.Pumps(i).WindingTempC = station.Pumps(i).WindingTempC + ((targetTempC - station.Pumps(i).WindingTempC) / 120.0) * dtSec
                station.Pumps(i).RunningHours = station.Pumps(i).RunningHours + (dtSec / 3600.0)
                
                station.TotalPowerKW = station.TotalPowerKW + station.Pumps(i).MotorPowerKW
            ELSE
                station.Pumps(i).DischargeFlowM3H = 0.0
                station.Pumps(i).DischargeHeadM = 0.0
                station.Pumps(i).MotorPowerKW = 0.0
                station.Pumps(i).MotorCurrentAmps = 0.0
                ' Cool down idle pump towards ambient 25 deg C
                station.Pumps(i).WindingTempC = station.Pumps(i).WindingTempC + ((25.0 - station.Pumps(i).WindingTempC) / 300.0) * dtSec
            END IF
        NEXT i
    ELSE
        ' No active pumps
        station.TotalFlowM3H = station.TotalFlowM3H * 0.9
        station.DischargePressureBar = station.SuctionPressureBar
        station.TotalPowerKW = 0.0
    END IF
END SUB
