' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Sequential Phase Control & Equipment Actuation Logic
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sequence/phase_control.bas
' ==============================================================================
'
' This module implements executable batch phase procedures:
'   1. Solvent Dosing Phase
'   2. Reactor Heat-Up Phase
'   3. Exothermic Reaction Hold Phase
'   4. Quench Cooling Phase
'   5. Finished Product Transfer Phase
' ==============================================================================

' BatchUnitController: Tracks active phase progression on a reactor
TYPE BatchUnitController
    ActiveRecipeCode AS STRING
    CurrentStepIndex AS INTEGER
    TotalSteps       AS INTEGER
    StepElapsedTimeSec AS DOUBLE
    IsInterlockTripped AS INTEGER
    ValveDosingCommand AS DOUBLE
    AgitatorRunning    AS INTEGER
    TemperatureSp      AS DOUBLE
    ValveTransferOpen  AS INTEGER
END TYPE

' InitializeBatchUnit: Prepares reactor unit for execution
SUB InitializeBatchUnit(unit AS BatchUnitController, recipeCode AS STRING)
    unit.ActiveRecipeCode = recipeCode
    unit.CurrentStepIndex = 1
    unit.TotalSteps = 5
    unit.StepElapsedTimeSec = 0.0
    unit.IsInterlockTripped = 0
    unit.ValveDosingCommand = 0.0
    unit.AgitatorRunning = 0
    unit.TemperatureSp = 25.0
    unit.ValveTransferOpen = 0
END SUB

' ExecutePhaseStepCycle: Advances procedural sequence by dtSec
SUB ExecutePhaseStepCycle(unit AS BatchUnitController, currentReactorTemp AS DOUBLE, _
                          currentMassDosedKg AS DOUBLE, dtSec AS DOUBLE)
    IF unit.IsInterlockTripped = 1 THEN
        ' Safety interlock active: Fail-safe shutdown
        unit.ValveDosingCommand = 0.0
        unit.ValveTransferOpen = 0
        EXIT SUB
    END IF

    unit.StepElapsedTimeSec = unit.StepElapsedTimeSec + dtSec

    ' Step 1: Dosing Solvent (Target: 500.0 kg)
    IF unit.CurrentStepIndex = 1 THEN
        unit.AgitatorRunning = 0
        unit.TemperatureSp = 25.0
        unit.ValveTransferOpen = 0
        IF currentMassDosedKg < 500.0 THEN
            unit.ValveDosingCommand = 100.0
        ELSE
            unit.ValveDosingCommand = 0.0
            ' Advance to Step 2
            unit.CurrentStepIndex = 2
            unit.StepElapsedTimeSec = 0.0
        END IF

    ' Step 2: Start Agitator and Heat Up to 80.0 deg C
    ELSEIF unit.CurrentStepIndex = 2 THEN
        unit.ValveDosingCommand = 0.0
        unit.AgitatorRunning = 1
        unit.TemperatureSp = 80.0
        unit.ValveTransferOpen = 0
        IF currentReactorTemp >= 79.5 THEN
            ' Advance to Step 3
            unit.CurrentStepIndex = 3
            unit.StepElapsedTimeSec = 0.0
        END IF

    ' Step 3: Exothermic Reaction Hold for 300.0 seconds
    ELSEIF unit.CurrentStepIndex = 3 THEN
        unit.ValveDosingCommand = 0.0
        unit.AgitatorRunning = 1
        unit.TemperatureSp = 80.0
        unit.ValveTransferOpen = 0
        IF unit.StepElapsedTimeSec >= 300.0 THEN
            ' Advance to Step 4
            unit.CurrentStepIndex = 4
            unit.StepElapsedTimeSec = 0.0
        END IF

    ' Step 4: Quench Cooling down to 35.0 deg C
    ELSEIF unit.CurrentStepIndex = 4 THEN
        unit.ValveDosingCommand = 0.0
        unit.AgitatorRunning = 1
        unit.TemperatureSp = 25.0  ' Force cooling
        unit.ValveTransferOpen = 0
        IF currentReactorTemp <= 35.0 THEN
            ' Advance to Step 5
            unit.CurrentStepIndex = 5
            unit.StepElapsedTimeSec = 0.0
        END IF

    ' Step 5: Transfer Product to Storage
    ELSEIF unit.CurrentStepIndex = 5 THEN
        unit.ValveDosingCommand = 0.0
        unit.AgitatorRunning = 0
        unit.ValveTransferOpen = 1
    END IF
END SUB
