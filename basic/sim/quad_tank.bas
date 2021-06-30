' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Quadruple-Tank Non-Linear Process Digital Twin Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/quad_tank.bas
' ==============================================================================
'
' This module implements the classic Karl Henrik Johansson Quadruple-Tank
' benchmark process. Four interconnected liquid tanks are fed by two pumps
' through multi-position three-way ratio split valves:
'   Pump 1 flows into Tank 1 (fraction gamma1) and Tank 4 (fraction 1 - gamma1)
'   Pump 2 flows into Tank 2 (fraction gamma2) and Tank 3 (fraction 1 - gamma2)
'   Tank 3 discharges by gravity into Tank 1
'   Tank 4 discharges by gravity into Tank 2
' Demonstrates multivariable interacting dynamics and non-minimum phase zeros.
' ==============================================================================

CONST GRAVITY_ACCEL = 981.0  ' cm/s^2

' QuadTankState: Physical dimensions and state variables
TYPE QuadTankState
    ' Tank Liquid Levels (h1, h2, h3, h4 in cm)
    H1 AS DOUBLE : H2 AS DOUBLE : H3 AS DOUBLE : H4 AS DOUBLE

    ' Tank Cross-Sectional Areas (cm^2)
    Area1 AS DOUBLE : Area2 AS DOUBLE : Area3 AS DOUBLE : Area4 AS DOUBLE

    ' Discharge Orifice Outflow Cross-Sections (cm^2)
    OutArea1 AS DOUBLE : OutArea2 AS DOUBLE : OutArea3 AS DOUBLE : OutArea4 AS DOUBLE

    ' Pump Flow Ratio Split Factors (gamma1, gamma2 in [0, 1])
    Gamma1 AS DOUBLE : Gamma2 AS DOUBLE

    ' Pump Voltage-to-Flow Proportionality Constants (cm^3/s per Volt)
    K1 AS DOUBLE : K2 AS DOUBLE
END TYPE

' InitializeQuadTank: Sets standard Johansson benchmark physical constants
SUB InitializeQuadTank(sim AS QuadTankState, g1 AS DOUBLE, g2 AS DOUBLE)
    sim.H1 = 12.4
    sim.H2 = 12.7
    sim.H3 = 1.8
    sim.H4 = 1.4

    sim.Area1 = 139.0 : sim.Area2 = 139.0 : sim.Area3 = 139.0 : sim.Area4 = 139.0
    sim.OutArea1 = 0.071 : sim.OutArea2 = 0.057 : sim.OutArea3 = 0.071 : sim.OutArea4 = 0.057

    sim.Gamma1 = g1  ' e.g. 0.70 for minimum phase, 0.30 for non-minimum phase
    sim.Gamma2 = g2  ' e.g. 0.60 for minimum phase, 0.40 for non-minimum phase

    sim.K1 = 3.33    ' cm^3 / (s * V)
    sim.K2 = 3.35    ' cm^3 / (s * V)
END SUB

' StepQuadTankEuler: Advances tank levels by dt seconds given pump voltages v1, v2
' Non-linear differential equations (Torricelli drainage):
'   dh1/dt = - (a1/A1)*sqrt(2*g*h1) + (a3/A1)*sqrt(2*g*h3) + (gamma1*k1/A1)*v1
'   dh2/dt = - (a2/A2)*sqrt(2*g*h2) + (a4/A2)*sqrt(2*g*h4) + (gamma2*k2/A2)*v2
'   dh3/dt = - (a3/A3)*sqrt(2*g*h3) + ((1 - gamma2)*k2/A3)*v2
'   dh4/dt = - (a4/A4)*sqrt(2*g*h4) + ((1 - gamma1)*k1/A4)*v1
SUB StepQuadTankEuler(sim AS QuadTankState, voltPump1 AS DOUBLE, voltPump2 AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB

    voltPump1 = ClampValue(voltPump1, 0.0, 10.0)
    voltPump2 = ClampValue(voltPump2, 0.0, 10.0)

    ' Safe Torricelli outflow calculations
    DIM outFlow1 AS DOUBLE : outFlow1 = sim.OutArea1 * SQR(2.0 * GRAVITY_ACCEL * ClampValue(sim.H1, 0.0, 1000.0))
    DIM outFlow2 AS DOUBLE : outFlow2 = sim.OutArea2 * SQR(2.0 * GRAVITY_ACCEL * ClampValue(sim.H2, 0.0, 1000.0))
    DIM outFlow3 AS DOUBLE : outFlow3 = sim.OutArea3 * SQR(2.0 * GRAVITY_ACCEL * ClampValue(sim.H3, 0.0, 1000.0))
    DIM outFlow4 AS DOUBLE : outFlow4 = sim.OutArea4 * SQR(2.0 * GRAVITY_ACCEL * ClampValue(sim.H4, 0.0, 1000.0))

    ' Pump inflows
    DIM inFlow1 AS DOUBLE : inFlow1 = sim.Gamma1 * sim.K1 * voltPump1
    DIM inFlow2 AS DOUBLE : inFlow2 = sim.Gamma2 * sim.K2 * voltPump2
    DIM inFlow3 AS DOUBLE : inFlow3 = (1.0 - sim.Gamma2) * sim.K2 * voltPump2
    DIM inFlow4 AS DOUBLE : inFlow4 = (1.0 - sim.Gamma1) * sim.K1 * voltPump1

    ' Derivatives
    DIM dh1_dt AS DOUBLE : dh1_dt = (-outFlow1 + outFlow3 + inFlow1) / sim.Area1
    DIM dh2_dt AS DOUBLE : dh2_dt = (-outFlow2 + outFlow4 + inFlow2) / sim.Area2
    DIM dh3_dt AS DOUBLE : dh3_dt = (-outFlow3 + inFlow3) / sim.Area3
    DIM dh4_dt AS DOUBLE : dh4_dt = (-outFlow4 + inFlow4) / sim.Area4

    ' Explicit numerical integration
    sim.H1 = sim.H1 + dh1_dt * dtSec
    sim.H2 = sim.H2 + dh2_dt * dtSec
    sim.H3 = sim.H3 + dh3_dt * dtSec
    sim.H4 = sim.H4 + dh4_dt * dtSec

    ' Clamp to physical tank heights (0 to 30 cm)
    sim.H1 = ClampValue(sim.H1, 0.0, 30.0)
    sim.H2 = ClampValue(sim.H2, 0.0, 30.0)
    sim.H3 = ClampValue(sim.H3, 0.0, 30.0)
    sim.H4 = ClampValue(sim.H4, 0.0, 30.0)
END SUB
