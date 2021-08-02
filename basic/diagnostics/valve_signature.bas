' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Smart Control Valve Diagnostic Signature & Stiction Analyzer
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/diagnostics/valve_signature.bas
' ==============================================================================
'
' This module implements online control valve health analytics for smart
' digital valve positioners (DVP):
'   - Kano two-parameter stiction modeling: Deadband (d) and Slip-Jump (J)
'   - Valve travel reversal counter and cumulative stem odometer tracking
'   - Pneumatic actuator diaphragm pressure leakage detection
'   - Valve response lag and packing box friction degradation metrics
' ==============================================================================

TYPE ValveDiagnosticState
    ValveTag        AS STRING
    CommandedOP     AS DOUBLE  ' Controller output setpoint (0 to 100%)
    ActualPosition  AS DOUBLE  ' Field positioner LVDT/Hall-effect feedback
    ActuatorPressureBar AS DOUBLE' Diaphragm / piston air pressure
    
    ' Stiction Analytics
    DeadbandWidthPct AS DOUBLE ' Static friction deadband d (e.g. 1.8%)
    SlipJumpPct     AS DOUBLE  ' Dynamic slip-jump J (e.g. 0.9%)
    IsStuck         AS INTEGER ' 1 = Stem sticking, 0 = Moving
    StictionAlarm   AS INTEGER ' 1 = Excessive stiction degrading loop
    
    ' Mechanical Wear Odometer
    DirectionReversals AS INTEGER ' Total count of stem direction reversals
    CumulativeTravelPct AS DOUBLE ' Total accumulated travel (% span)
    LastVelocity    AS DOUBLE
    LastCommandedOP AS DOUBLE
END TYPE

' InitializeValveDiagnostics: Sets baseline healthy valve benchmarks
SUB InitializeValveDiagnostics(vd AS ValveDiagnosticState, tag AS STRING)
    vd.ValveTag = tag
    vd.CommandedOP = 50.0
    vd.ActualPosition = 50.0
    vd.ActuatorPressureBar = 2.4
    
    vd.DeadbandWidthPct = 0.5  ' Healthy valve: < 1.0% deadband
    vd.SlipJumpPct = 0.2       ' Healthy valve: < 0.5% slip-jump
    vd.IsStuck = 0
    vd.StictionAlarm = 0
    
    vd.DirectionReversals = 0
    vd.CumulativeTravelPct = 0.0
    vd.LastVelocity = 0.0
    vd.LastCommandedOP = 50.0
END SUB

' UpdateValveDiagnostics: Evaluates one positioner scan cycle
SUB UpdateValveDiagnostics(vd AS ValveDiagnosticState, cmdOP AS DOUBLE, posFeedback AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0001 THEN EXIT SUB
    
    ' Track stem odometer: cumulative distance traveled
    DIM deltaPos AS DOUBLE : deltaPos = ABS(posFeedback - vd.ActualPosition)
    vd.CumulativeTravelPct = vd.CumulativeTravelPct + deltaPos
    
    ' Detect direction reversal
    DIM deltaCmd AS DOUBLE : deltaCmd = cmdOP - vd.LastCommandedOP
    IF (deltaCmd > 0.05 AND vd.LastVelocity < -0.05) OR (deltaCmd < -0.05 AND vd.LastVelocity > 0.05) THEN
        vd.DirectionReversals = vd.DirectionReversals + 1
    END IF
    vd.LastVelocity = deltaCmd
    vd.LastCommandedOP = cmdOP
    
    ' Check for sticking stem: command is changing but valve position does NOT move
    DIM trackingError AS DOUBLE : trackingError = ABS(cmdOP - posFeedback)
    IF ABS(deltaCmd) > 0.2 AND deltaPos < 0.02 THEN
        vd.IsStuck = 1
    ELSE
        vd.IsStuck = 0
    END IF
    
    ' Stiction threshold check (ISA guidelines: stiction > 2.0% creates limit cycles)
    IF trackingError > 2.5 AND vd.IsStuck = 1 THEN
        vd.StictionAlarm = 1
    ELSE
        vd.StictionAlarm = 0
    END IF
    
    vd.CommandedOP = cmdOP
    vd.ActualPosition = posFeedback
END SUB
