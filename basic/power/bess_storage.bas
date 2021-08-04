' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Battery Energy Storage System (BESS) & Microgrid Dispatch Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/power/bess_storage.bas
' ==============================================================================
'
' This module implements the electrochemical, electrical, and supervisory
' control dynamics for a 5 MW / 10 MWh lithium iron phosphate (LFP) BESS:
'   - Coulomb counting State of Charge (SoC) integration
'   - Non-linear Open-Circuit Voltage (OCV) vs SoC curve
'   - Active power charge / discharge setpoint tracking
'   - Battery cell internal resistance (I^2 * R) joule heating
'   - Liquid cooling chiller temperature regulation
' ==============================================================================

TYPE BessStorageState
    ' Nameplate Ratings
    RatedCapacityKWh AS DOUBLE ' Total energy capacity (10,000 kWh = 10 MWh)
    RatedPowerKW     AS DOUBLE ' Inverter continuous power rating (5,000 kW = 5 MW)
    NominalVoltageV  AS DOUBLE ' 800V DC nominal pack voltage
    InternalResistanceOhm AS DOUBLE ' Pack internal series resistance R_int (0.008 Ohm)
    
    ' Real-Time Electrical State
    StateOfChargePct AS DOUBLE ' SoC (nominal 10% to 90% operating window)
    PackVoltageV     AS DOUBLE ' Terminal voltage under load
    PackCurrentAmps  AS DOUBLE ' Positive = Discharge, Negative = Charge
    ActivePowerKW    AS DOUBLE ' Terminal power (+ = Discharging, - = Charging)
    PowerSetpointKW  AS DOUBLE ' Commanded dispatch setpoint from SCADA
    
    ' Thermal State
    CellTemperatureC AS DOUBLE ' Internal cell temperature (nominal 25.0 to 35.0 deg C)
    CoolingChillerKW AS DOUBLE ' Thermal extraction rate
    OverTempAlarm    AS INTEGER
END TYPE

' InitializeBessStorage: Configures 5 MW / 10 MWh industrial LFP battery
SUB InitializeBessStorage(bess AS BessStorageState)
    bess.RatedCapacityKWh = 10000.0
    bess.RatedPowerKW = 5000.0
    bess.NominalVoltageV = 800.0
    bess.InternalResistanceOhm = 0.008
    
    bess.StateOfChargePct = 65.0   ' 65% initial charge
    bess.PackVoltageV = 812.0
    bess.PackCurrentAmps = 0.0
    bess.ActivePowerKW = 0.0
    bess.PowerSetpointKW = 0.0
    
    bess.CellTemperatureC = 26.5
    bess.CoolingChillerKW = 25.0
    bess.OverTempAlarm = 0
END SUB

' StepBessCycle: Advances electrochemical and thermal battery states
SUB StepBessCycle(bess AS BessStorageState, targetPowerKW AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    ' Bound requested power to inverter rating
    bess.PowerSetpointKW = ClampValue(targetPowerKW, -bess.RatedPowerKW, bess.RatedPowerKW)
    
    ' Enforce SoC operational boundaries (10% min, 90% max)
    IF bess.StateOfChargePct >= 90.0 AND bess.PowerSetpointKW < 0.0 THEN
        bess.PowerSetpointKW = 0.0 ' Prevent overcharging
    ELSEIF bess.StateOfChargePct <= 10.0 AND bess.PowerSetpointKW > 0.0 THEN
        bess.PowerSetpointKW = 0.0 ' Prevent overdischarging
    END IF
    
    ' 1. OCV estimation from SoC: V_ocv = 760 + 0.8 * SoC
    DIM ocvVolts AS DOUBLE : ocvVolts = 760.0 + (bess.StateOfChargePct * 0.8)
    
    ' 2. Calculate current: I approx P / V_ocv
    bess.ActivePowerKW = bess.PowerSetpointKW
    bess.PackCurrentAmps = (bess.ActivePowerKW * 1000.0) / ocvVolts
    
    ' Terminal voltage: V_term = V_ocv - I * R_int
    bess.PackVoltageV = ocvVolts - (bess.PackCurrentAmps * bess.InternalResistanceOhm)
    
    ' 3. Coulomb Counting SoC Integration:
    ' dSoC/dt = - (I * dt) / (Capacity_Ah * 3600)
    ' Capacity_Ah = (RatedCapacityKWh * 1000) / NominalVoltageV = 10,000,000 / 800 = 12,500 Ah
    DIM capacityAh AS DOUBLE : capacityAh = 12500.0
    DIM deltaSoC AS DOUBLE : deltaSoC = -(bess.PackCurrentAmps * dtSec / (capacityAh * 3600.0)) * 100.0
    bess.StateOfChargePct = ClampValue(bess.StateOfChargePct + deltaSoC, 0.0, 100.0)
    
    ' 4. Thermal Dynamics: I^2 * R heating vs Chiller cooling
    DIM jouleHeatKW AS DOUBLE
    jouleHeatKW = (bess.PackCurrentAmps * bess.PackCurrentAmps * bess.InternalResistanceOhm) / 1000.0
    
    ' Net thermal load: dT/dt = (Q_joule - Q_cool) / ThermalMass
    DIM netHeatKW AS DOUBLE : netHeatKW = jouleHeatKW - bess.CoolingChillerKW
    DIM dTempC AS DOUBLE : dTempC = (netHeatKW / 1200.0) * dtSec ' Thermal mass ~1200 kJ/K
    bess.CellTemperatureC = bess.CellTemperatureC + dTempC
    
    ' Over-temperature alarm threshold (45 deg C)
    IF bess.CellTemperatureC > 45.0 THEN
        bess.OverTempAlarm = 1
    ELSE
        bess.OverTempAlarm = 0
    END IF
END SUB
