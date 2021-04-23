' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Dual-Actuator Split-Range Sequencing & Valve Characterization
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/split_range.bas
' ==============================================================================
'
' This module implements split-range sequencing for dual-valve systems
' (e.g., heating steam valve A and cooling water valve B driven by one controller).
' Includes an energy-saving neutral deadband gap to prevent simultaneous opening.
' ==============================================================================

CONST VALVE_CHAR_LINEAR       = 0
CONST VALVE_CHAR_EQUAL_PCT    = 1
CONST VALVE_CHAR_QUICK_OPEN   = 2

' SplitRangeConfiguration: Geometry and characteristics of dual valves
TYPE SplitRangeConfiguration
    SplitMidpoint   AS DOUBLE  ' Nominal crossover point (e.g. 50.0%)
    NeutralGapPct   AS DOUBLE  ' Deadband gap where both valves are closed (e.g. 4.0%)
    ValveAChar      AS INTEGER ' Characterization: Linear, Equal-Pct, Quick-Open
    ValveBChar      AS INTEGER ' Characterization: Linear, Equal-Pct, Quick-Open
    ValveAInvert    AS INTEGER ' 1 if Valve A closes as controller output rises
    ValveBInvert    AS INTEGER ' 1 if Valve B closes as controller output rises
END TYPE

' ApplyValveCharacterization: Applies aerodynamic/hydraulic flow trim curve
FUNCTION ApplyValveCharacterization(signalFraction AS DOUBLE, charType AS INTEGER) AS DOUBLE
    signalFraction = ClampValue(signalFraction, 0.0, 1.0)
    IF charType = VALVE_CHAR_LINEAR THEN
        RETURN signalFraction
    ELSEIF charType = VALVE_CHAR_EQUAL_PCT THEN
        ' Equal percentage valve curve: R^(x - 1) with rangeability R = 50
        IF signalFraction <= 0.001 THEN RETURN 0.0
        DIM rangeability AS DOUBLE : rangeability = 50.0
        RETURN (EXP(signalFraction * LOG(rangeability)) - 1.0) / (rangeability - 1.0)
    ELSEIF charType = VALVE_CHAR_QUICK_OPEN THEN
        ' Quick opening square root curve
        RETURN SQR(signalFraction)
    END IF
    RETURN signalFraction
END FUNCTION

' ComputeSplitRangeOutputs: Splits master controller command into Valve A and Valve B positions
SUB ComputeSplitRangeOutputs(cfg AS SplitRangeConfiguration, controllerOp AS DOUBLE, _
                            valveAOp AS DOUBLE, valveBOp AS DOUBLE)
    DIM halfGap AS DOUBLE : halfGap = cfg.NeutralGapPct * 0.5
    DIM aUpperLimit AS DOUBLE : aUpperLimit = cfg.SplitMidpoint - halfGap
    DIM bLowerLimit AS DOUBLE : bLowerLimit = cfg.SplitMidpoint + halfGap

    ' Valve A Evaluation (e.g. Heating Medium)
    IF controllerOp <= aUpperLimit THEN
        DIM fracA AS DOUBLE
        fracA = (aUpperLimit - controllerOp) / aUpperLimit
        IF cfg.ValveAInvert = 0 THEN fracA = 1.0 - fracA
        valveAOp = ApplyValveCharacterization(fracA, cfg.ValveAChar) * 100.0
    ELSE
        valveAOp = 0.0
    END IF

    ' Valve B Evaluation (e.g. Cooling Medium)
    IF controllerOp >= bLowerLimit THEN
        DIM fracB AS DOUBLE
        DIM spanB AS DOUBLE : spanB = 100.0 - bLowerLimit
        IF spanB > 0.0 THEN
            fracB = (controllerOp - bLowerLimit) / spanB
        ELSE
            fracB = 0.0
        END IF
        IF cfg.ValveBInvert = 1 THEN fracB = 1.0 - fracB
        valveBOp = ApplyValveCharacterization(fracB, cfg.ValveBChar) * 100.0
    ELSE
        valveBOp = 0.0
    END IF

    valveAOp = ClampValue(valveAOp, 0.0, 100.0)
    valveBOp = ClampValue(valveBOp, 0.0, 100.0)
END SUB
