' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' IEC 61508 / 61511 Functional Safety PFD_avg & Proof-Testing Manager
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/safety/proof_test.bas
' ==============================================================================
'
' This module implements the mathematical failure rate and reliability models
' defined in IEC 61508 and IEC 61511 for Safety Instrumented Systems (SIS):
'   - Average Probability of Failure on Demand (PFD_avg) calculations
'   - Standard architecture architectures: 1oo1, 1oo2, 2oo3 (TMR)
'   - Beta common-cause failure fraction modeling
'   - Proof Test Interval (TI) tracking and Proof Test Coverage (PTC)
'   - Automated SIL determination: SIL 1, SIL 2, SIL 3, SIL 4
' ==============================================================================

' Safety Integrity Level Targets (Low Demand Mode)
CONST SIL_NONE = 0
CONST SIL_1    = 1 ' 10^-2 <= PFD < 10^-1
CONST SIL_2    = 2 ' 10^-3 <= PFD < 10^-2
CONST SIL_3    = 3 ' 10^-4 <= PFD < 10^-3
CONST SIL_4    = 4 ' 10^-5 <= PFD < 10^-4

TYPE SifReliabilityModel
    SifTag          AS STRING  ' Safety Instrumented Function Identifier
    Architecture    AS STRING  ' "1oo1", "1oo2", "2oo3"
    LambdaDU        AS DOUBLE  ' Dangerous undetected failure rate (failures / hour)
    ProofTestIntHours AS DOUBLE' Proof test interval T_I (e.g. 8760.0 hours = 1 year)
    CommonCauseBeta AS DOUBLE  ' Common cause beta factor (e.g. 0.05 = 5%)
    ProofCoveragePTC AS DOUBLE ' Proof test effectiveness factor (e.g. 0.90 = 90%)
    
    ComputedPfdAvg  AS DOUBLE
    AchievedSilLevel AS INTEGER
    HoursSinceLastTest AS DOUBLE
    TestDueWarning  AS INTEGER
END TYPE

' ComputePfdAvg1oo1: PFD_avg = 0.5 * lambda_DU * T_I
FUNCTION ComputePfdAvg1oo1(lambdaDU AS DOUBLE, tHours AS DOUBLE) AS DOUBLE
    ComputePfdAvg1oo1 = 0.5 * lambdaDU * tHours
END FUNCTION

' ComputePfdAvg1oo2: PFD_avg = (1/3) * (lambda_DU * T_I)^2 + 0.5 * beta * lambda_DU * T_I
FUNCTION ComputePfdAvg1oo2(lambdaDU AS DOUBLE, tHours AS DOUBLE, beta AS DOUBLE) AS DOUBLE
    DIM indTerm AS DOUBLE : indTerm = (1.0 / 3.0) * (lambdaDU * tHours) * (lambdaDU * tHours)
    DIM ccTerm AS DOUBLE : ccTerm = 0.5 * beta * lambdaDU * tHours
    ComputePfdAvg1oo2 = indTerm + ccTerm
END FUNCTION

' ComputePfdAvg2oo3: PFD_avg = (lambda_DU * T_I)^2 + 0.5 * beta * lambda_DU * T_I
FUNCTION ComputePfdAvg2oo3(lambdaDU AS DOUBLE, tHours AS DOUBLE, beta AS DOUBLE) AS DOUBLE
    DIM indTerm AS DOUBLE : indTerm = (lambdaDU * tHours) * (lambdaDU * tHours)
    DIM ccTerm AS DOUBLE : ccTerm = 0.5 * beta * lambdaDU * tHours
    ComputePfdAvg2oo3 = indTerm + ccTerm
END FUNCTION

' EvaluateSilLevel: Maps computed PFD_avg to IEC 61508 SIL level
FUNCTION EvaluateSilLevel(pfdVal AS DOUBLE) AS INTEGER
    IF pfdVal >= 0.10 THEN
        EvaluateSilLevel = SIL_NONE
    ELSEIF pfdVal >= 0.010 THEN
        EvaluateSilLevel = SIL_1
    ELSEIF pfdVal >= 0.0010 THEN
        EvaluateSilLevel = SIL_2
    ELSEIF pfdVal >= 0.00010 THEN
        EvaluateSilLevel = SIL_3
    ELSE
        EvaluateSilLevel = SIL_4
    END IF
END FUNCTION

' UpdateSifReliability: Computes current safety integrity metrics
SUB UpdateSifReliability(sif AS SifReliabilityModel)
    IF sif.Architecture = "1oo1" THEN
        sif.ComputedPfdAvg = ComputePfdAvg1oo1(sif.LambdaDU, sif.ProofTestIntHours)
    ELSEIF sif.Architecture = "1oo2" THEN
        sif.ComputedPfdAvg = ComputePfdAvg1oo2(sif.LambdaDU, sif.ProofTestIntHours, sif.CommonCauseBeta)
    ELSEIF sif.Architecture = "2oo3" THEN
        sif.ComputedPfdAvg = ComputePfdAvg2oo3(sif.LambdaDU, sif.ProofTestIntHours, sif.CommonCauseBeta)
    ELSE
        sif.ComputedPfdAvg = ComputePfdAvg1oo1(sif.LambdaDU, sif.ProofTestIntHours)
    END IF
    
    sif.AchievedSilLevel = EvaluateSilLevel(sif.ComputedPfdAvg)
    
    ' Proof test schedule supervision
    IF sif.HoursSinceLastTest >= (sif.ProofTestIntHours * 0.90) THEN
        sif.TestDueWarning = 1
    ELSE
        sif.TestDueWarning = 0
    END IF
END SUB
