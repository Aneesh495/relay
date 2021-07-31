' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' 16x16 Emergency Shutdown (ESD) Cause & Effect Matrix Solver
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/safety/esd_matrix.bas
' ==============================================================================
'
' This module implements the executive shutdown solver for high-integrity
' Emergency Shutdown (ESD) / Safety Instrumented Systems (SIS):
'   - 16 Initiating Cause inputs (Sensors, Gas detectors, Pushbuttons)
'   - 16 Final Effect outputs (Shutdown valves SDV, Blowdown BDV, Motor trips)
'   - De-energize-to-trip fail-safe logic (normally energized 24V DC coils)
'   - Latched trip memory requiring permissive clearing and manual reset
' ==============================================================================

CONST ESD_DIM = 16

TYPE EsdMatrixSolver
    CauseInput(16)      AS INTEGER ' 1 = Demand / Trip condition, 0 = Healthy
    EffectOutput(16)    AS INTEGER ' 1 = Actuated / Tripped, 0 = Normal
    LatchedEffect(16)   AS INTEGER ' Latched memory requiring manual reset
    Matrix(16, 16)      AS INTEGER ' 1 if Cause i triggers Effect j
    
    TotalActiveTrips    AS INTEGER
    ManualResetPermit   AS INTEGER ' 1 = Permitted to reset (all causes clear)
END TYPE

' InitializeEsdMatrix: Sets up Cause & Effect matrix associations
SUB InitializeEsdMatrix(esd AS EsdMatrixSolver)
    esd.TotalActiveTrips = 0
    esd.ManualResetPermit = 1
    
    DIM i AS INTEGER
    DIM j AS INTEGER
    FOR i = 1 TO ESD_DIM
        esd.CauseInput(i) = 0
        esd.EffectOutput(i) = 0
        esd.LatchedEffect(i) = 0
        FOR j = 1 TO ESD_DIM
            esd.Matrix(i, j) = 0
        NEXT j
    NEXT i
END SUB

' MapCauseToEffect: Associates initiating cause with safety effect
SUB MapCauseToEffect(esd AS EsdMatrixSolver, causeIdx AS INTEGER, effectIdx AS INTEGER)
    IF causeIdx >= 1 AND causeIdx <= ESD_DIM AND effectIdx >= 1 AND effectIdx <= ESD_DIM THEN
        esd.Matrix(causeIdx, effectIdx) = 1
    END IF
END SUB

' SolveEsdScanCycle: Solves boolean logic across Cause & Effect grid
SUB SolveEsdScanCycle(esd AS EsdMatrixSolver)
    esd.TotalActiveTrips = 0
    DIM allCausesClear AS INTEGER : allCausesClear = 1
    
    ' Check causes
    DIM i AS INTEGER
    DIM j AS INTEGER
    FOR i = 1 TO ESD_DIM
        IF esd.CauseInput(i) = 1 THEN
            allCausesClear = 0
            ' Trip all associated final effects
            FOR j = 1 TO ESD_DIM
                IF esd.Matrix(i, j) = 1 THEN
                    esd.EffectOutput(j) = 1
                    esd.LatchedEffect(j) = 1
                END IF
            NEXT j
        END IF
    NEXT i
    
    ' Maintain latched state for any previously tripped effect
    FOR j = 1 TO ESD_DIM
        IF esd.LatchedEffect(j) = 1 THEN
            esd.EffectOutput(j) = 1
            esd.TotalActiveTrips = esd.TotalActiveTrips + 1
        END IF
    NEXT j
    
    esd.ManualResetPermit = allCausesClear
END SUB

' ExecuteManualEsdReset: Operator reset command
FUNCTION ExecuteManualEsdReset(esd AS EsdMatrixSolver) AS INTEGER
    ' Reset is strictly rejected if ANY initiating cause remains tripped!
    IF esd.ManualResetPermit = 1 THEN
        DIM j AS INTEGER
        FOR j = 1 TO ESD_DIM
            esd.LatchedEffect(j) = 0
            esd.EffectOutput(j) = 0
        NEXT j
        esd.TotalActiveTrips = 0
        ExecuteManualEsdReset = 1 ' Reset successful
    ELSE
        ExecuteManualEsdReset = 0 ' Blocked: Active causes present!
    END IF
END FUNCTION
