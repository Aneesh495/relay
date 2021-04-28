' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Mamdani Fuzzy Logic Inference & Centroid Defuzzification Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/fuzzy_logic.bas
' ==============================================================================
'
' This module implements a Mamdani rule-based fuzzy logic controller (FLC).
' Designed for highly non-linear processes (e.g. chemical pH neutralization,
' biological fermentation) where classical linear PID controllers perform poorly.
' ==============================================================================

' TriangularMembership: Computes degree of membership in [0, 1] for triangle (a, b, c)
FUNCTION TriangularMembership(x AS DOUBLE, a AS DOUBLE, b AS DOUBLE, c AS DOUBLE) AS DOUBLE
    IF x <= a OR x >= c THEN RETURN 0.0
    IF x = b THEN RETURN 1.0
    IF x < b THEN
        RETURN (x - a) / (b - a)
    ELSE
        RETURN (c - x) / (c - b)
    END IF
END FUNCTION

' TrapezoidalMembership: Computes degree of membership in [0, 1] for trapezoid (a, b, c, d)
FUNCTION TrapezoidalMembership(x AS DOUBLE, a AS DOUBLE, b AS DOUBLE, c AS DOUBLE, d AS DOUBLE) AS DOUBLE
    IF x <= a OR x >= d THEN RETURN 0.0
    IF x >= b AND x <= c THEN RETURN 1.0
    IF x < b THEN
        RETURN (x - a) / (b - a)
    ELSE
        RETURN (d - x) / (d - c)
    END IF
END FUNCTION

' FuzzyControllerState: Linguistic variables and fuzzy set partitions
TYPE FuzzyControllerState
    ' Input 1: Error e (Negative, Zero, Positive)
    MuErrNeg        AS DOUBLE
    MuErrZero       AS DOUBLE
    MuErrPos        AS DOUBLE

    ' Input 2: Delta Error de (Negative, Zero, Positive)
    MuDErrNeg       AS DOUBLE
    MuDErrZero      AS DOUBLE
    MuDErrPos       AS DOUBLE

    ' Output Consequent Weights (Negative, Zero, Positive)
    RuleOutNeg      AS DOUBLE
    RuleOutZero     AS DOUBLE
    RuleOutPos      AS DOUBLE

    ScalingKe       AS DOUBLE  ' Input error scaling factor
    ScalingKde      AS DOUBLE  ' Input delta-error scaling factor
    ScalingKu       AS DOUBLE  ' Output gain scaling factor
END TYPE

' InitializeFuzzyController: Prepares normalization gains
SUB InitializeFuzzyController(flc AS FuzzyControllerState, ke AS DOUBLE, kde AS DOUBLE, ku AS DOUBLE)
    flc.ScalingKe = ke > 0.0 ? ke : 1.0
    flc.ScalingKde = kde > 0.0 ? kde : 1.0
    flc.ScalingKu = ku > 0.0 ? ku : 1.0
END SUB

' ExecuteFuzzyStep: Computes fuzzification, rule evaluation, and centroid defuzzification
FUNCTION ExecuteFuzzyStep(flc AS FuzzyControllerState, errorVal AS DOUBLE, deltaErrorVal AS DOUBLE) AS DOUBLE
    ' 1. Scale inputs
    DIM normErr AS DOUBLE : normErr = errorVal * flc.ScalingKe
    DIM normDErr AS DOUBLE : normDErr = deltaErrorVal * flc.ScalingKde

    ' 2. Fuzzification (Error)
    flc.MuErrNeg = TrapezoidalMembership(normErr, -100.0, -100.0, -1.0, 0.0)
    flc.MuErrZero = TriangularMembership(normErr, -1.0, 0.0, 1.0)
    flc.MuErrPos = TrapezoidalMembership(normErr, 0.0, 1.0, 100.0, 100.0)

    ' Fuzzification (Delta Error)
    flc.MuDErrNeg = TrapezoidalMembership(normDErr, -100.0, -100.0, -1.0, 0.0)
    flc.MuDErrZero = TriangularMembership(normDErr, -1.0, 0.0, 1.0)
    flc.MuDErrPos = TrapezoidalMembership(normDErr, 0.0, 1.0, 100.0, 100.0)

    ' 3. Rule Evaluation (Mamdani Min-Max Inference):
    ' Rule 1: IF Err is Neg AND DErr is Neg THEN Out is Neg
    ' Rule 2: IF Err is Neg AND DErr is Zero THEN Out is Neg
    ' Rule 3: IF Err is Neg AND DErr is Pos THEN Out is Zero
    ' Rule 4: IF Err is Zero AND DErr is Neg THEN Out is Neg
    ' Rule 5: IF Err is Zero AND DErr is Zero THEN Out is Zero
    ' Rule 6: IF Err is Zero AND DErr is Pos THEN Out is Pos
    ' Rule 7: IF Err is Pos AND DErr is Neg THEN Out is Zero
    ' Rule 8: IF Err is Pos AND DErr is Zero THEN Out is Pos
    ' Rule 9: IF Err is Pos AND DErr is Pos THEN Out is Pos

    DIM r1 AS DOUBLE : r1 = flc.MuErrNeg < flc.MuDErrNeg ? flc.MuErrNeg : flc.MuDErrNeg
    DIM r2 AS DOUBLE : r2 = flc.MuErrNeg < flc.MuDErrZero ? flc.MuErrNeg : flc.MuDErrZero
    DIM r3 AS DOUBLE : r3 = flc.MuErrNeg < flc.MuDErrPos ? flc.MuErrNeg : flc.MuDErrPos

    DIM r4 AS DOUBLE : r4 = flc.MuErrZero < flc.MuDErrNeg ? flc.MuErrZero : flc.MuDErrNeg
    DIM r5 AS DOUBLE : r5 = flc.MuErrZero < flc.MuDErrZero ? flc.MuErrZero : flc.MuDErrZero
    DIM r6 AS DOUBLE : r6 = flc.MuErrZero < flc.MuDErrPos ? flc.MuErrZero : flc.MuDErrPos

    DIM r7 AS DOUBLE : r7 = flc.MuErrPos < flc.MuDErrNeg ? flc.MuErrPos : flc.MuDErrNeg
    DIM r8 AS DOUBLE : r8 = flc.MuErrPos < flc.MuDErrZero ? flc.MuErrPos : flc.MuDErrZero
    DIM r9 AS DOUBLE : r9 = flc.MuErrPos < flc.MuDErrPos ? flc.MuErrPos : flc.MuDErrPos

    ' Aggregate rule consequents (Max operator)
    DIM wNeg AS DOUBLE : wNeg = r1
    IF r2 > wNeg THEN wNeg = r2
    IF r4 > wNeg THEN wNeg = r4

    DIM wZero AS DOUBLE : wZero = r3
    IF r5 > wZero THEN wZero = r5
    IF r7 > wZero THEN wZero = r7

    DIM wPos AS DOUBLE : wPos = r6
    IF r8 > wPos THEN wPos = r8
    IF r9 > wPos THEN wPos = r9

    ' 4. Center of Gravity (Centroid) Defuzzification:
    ' Output Singletons: Neg = -1.0, Zero = 0.0, Pos = +1.0
    DIM numerator AS DOUBLE : numerator = wNeg * (-1.0) + wZero * (0.0) + wPos * (1.0)
    DIM denominator AS DOUBLE : denominator = wNeg + wZero + wPos

    DIM crispOutput AS DOUBLE
    IF denominator > 1.0E-6 THEN
        crispOutput = numerator / denominator
    ELSE
        crispOutput = 0.0
    END IF

    RETURN crispOutput * flc.ScalingKu
END FUNCTION
