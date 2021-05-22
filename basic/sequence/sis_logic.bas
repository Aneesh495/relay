' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Safety Instrumented Systems (SIS) & Emergency Shutdown (ESD) Matrix
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sequence/sis_logic.bas
' ==============================================================================
'
' This module implements Safety Instrumented Systems (SIS) logic conforming to
' IEC 61508 / IEC 61511. It evaluates Cause & Effect matrices to execute
' deterministic emergency shutdown (ESD) actions across chemical process units.
' ==============================================================================

CONST MAX_SIS_CAUSES  = 16
CONST MAX_SIS_EFFECTS = 16

' SisCauseEffectMatrix: Tabular representation of safety shutdowns
TYPE SisCauseEffectMatrix
    CauseCount      AS INTEGER
    EffectCount     AS INTEGER
    Matrix(256)     AS INTEGER  ' 16x16 binary matrix: Index = row*16 + col
    CauseStates(16) AS INTEGER  ' Monitored initiator trips (1 if tripped)
    EffectStates(16) AS INTEGER ' Resulting actuator actions (1 if triggered)
    IsSystemTripped AS INTEGER  ' 1 if any ESD action is actively commanded
END TYPE

' InitializeSisMatrix: Configures empty Cause & Effect grid
SUB InitializeSisMatrix(sis AS SisCauseEffectMatrix, nCauses AS INTEGER, nEffects AS INTEGER)
    sis.CauseCount = nCauses <= MAX_SIS_CAUSES ? nCauses : MAX_SIS_CAUSES
    sis.EffectCount = nEffects <= MAX_SIS_EFFECTS ? nEffects : MAX_SIS_EFFECTS
    sis.IsSystemTripped = 0

    DIM i AS INTEGER
    FOR i = 0 TO 255
        sis.Matrix(i) = 0
    NEXT i
    FOR i = 0 TO MAX_SIS_CAUSES - 1
        sis.CauseStates(i) = 0
        sis.EffectStates(i) = 0
    NEXT i
END SUB

' SetSisMapping: Establishes a shutdown relationship (Cause row triggers Effect col)
SUB SetSisMapping(sis AS SisCauseEffectMatrix, causeIndex AS INTEGER, effectIndex AS INTEGER, isActive AS INTEGER)
    IF causeIndex >= 0 AND causeIndex < sis.CauseCount AND effectIndex >= 0 AND effectIndex < sis.EffectCount THEN
        DIM cellIdx AS INTEGER
        cellIdx = causeIndex * 16 + effectIndex
        sis.Matrix(cellIdx) = isActive
    END IF
END SUB

' EvaluateSisLogic: Solves the Cause & Effect matrix to determine required shutdowns
SUB EvaluateSisLogic(sis AS SisCauseEffectMatrix)
    sis.IsSystemTripped = 0
    DIM col AS INTEGER
    DIM row AS INTEGER

    ' Evaluate each Effect output column
    FOR col = 0 TO sis.EffectCount - 1
        DIM effectDemand AS INTEGER : effectDemand = 0
        FOR row = 0 TO sis.CauseCount - 1
            DIM cellIdx AS INTEGER : cellIdx = row * 16 + col
            IF sis.Matrix(cellIdx) = 1 AND sis.CauseStates(row) = 1 THEN
                ' Cause is tripped and mapped to this effect!
                effectDemand = 1
                sis.IsSystemTripped = 1
            END IF
        NEXT row
        sis.EffectStates(col) = effectDemand
    NEXT col
END SUB
