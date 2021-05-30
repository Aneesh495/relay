' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Master & Control Recipe Execution Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sequence/recipes.bas
' ==============================================================================
'
' This module implements ISA-88 recipe management. Recipes define the Bill of
' Materials (BOM), target phase setpoints, sequence ordering, and completion
' criteria for chemical and pharmaceutical batch production.
' ==============================================================================

CONST MAX_RECIPE_STEPS = 12

' RecipeStepRecord: Defines single procedural phase step
TYPE RecipeStepRecord
    StepNumber      AS INTEGER  ' Sequence index 1, 2, 3...
    PhaseType       AS INTEGER  ' 1: Dosing, 2: Agitation, 3: Heating, 4: Reaction, 5: Transfer
    TargetSetpoint  AS DOUBLE   ' Target process engineering value (e.g. 85.0 deg C or 500.0 kg)
    ToleranceBand   AS DOUBLE   ' Allowable arrival deadband
    HoldDurationSec AS DOUBLE   ' Required holding time once setpoint reached
    IsStepComplete  AS INTEGER  ' 1 if step criteria satisfied
END TYPE

' MasterRecipeDefinition: Complete batch production specification
TYPE MasterRecipeDefinition
    RecipeId        AS STRING   ' Recipe code (e.g., POLYMER_A24)
    ProductName     AS STRING   ' Chemical product title
    NominalBatchKg  AS DOUBLE   ' Standard batch lot size in kg
    StepCount       AS INTEGER  ' Total sequence steps in recipe
    Steps(12)       AS RecipeStepRecord
END TYPE

' InitializeRecipeStep: Configures single phase parameter
SUB InitializeRecipeStep(step AS RecipeStepRecord, stepNum AS INTEGER, pType AS INTEGER, _
                         sp AS DOUBLE, tol AS DOUBLE, holdSec AS DOUBLE)
    step.StepNumber = stepNum
    step.PhaseType = pType
    step.TargetSetpoint = sp
    step.ToleranceBand = tol > 0.0 ? tol : 0.5
    step.HoldDurationSec = holdSec
    step.IsStepComplete = 0
END SUB

' CheckStepCompletionCriteria: Verifies whether measured value satisfies step completion
FUNCTION CheckStepCompletionCriteria(step AS RecipeStepRecord, measuredValue AS DOUBLE, _
                                     elapsedHoldSec AS DOUBLE) AS INTEGER
    DIM diff AS DOUBLE
    diff = ABS(measuredValue - step.TargetSetpoint)

    ' 1. Check if measured value is within tolerance band
    IF diff <= step.ToleranceBand THEN
        ' 2. Check if required hold duration has elapsed
        IF elapsedHoldSec >= step.HoldDurationSec THEN
            step.IsStepComplete = 1
            RETURN 1
        END IF
    END IF

    step.IsStepComplete = 0
    RETURN 0
END FUNCTION
