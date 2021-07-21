' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Batch Cooling Crystallizer & Crystal Population Balance (PBM) Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/batch_crystallizer.bas
' ==============================================================================
'
' This module implements the population balance equations (PBE) and moment
' transformations for a fine-chemical / pharmaceutical batch cooling crystallizer:
'   - Temperature-dependent saturation solubility curve C*(T)
'   - Relative supersaturation sigma = (C - C*) / C*
'   - Secondary nucleation rate B = k_b * sigma^b * M_T
'   - Crystal face linear growth rate G = k_g * sigma^g
'   - Method of Moments (mu_0, mu_1, mu_2, mu_3) for crystal size distribution
'   - Controlled cubic cooling trajectory maintaining metastable zone (MSZW)
' ==============================================================================

TYPE BatchCrystallizerState
    ' Thermal & Temporal State
    BatchTimeSec    AS DOUBLE  ' Elapsed process batch time
    BatchDurationSec AS DOUBLE ' Total recipe duration (e.g. 7200.0 sec)
    SlurryTempC     AS DOUBLE  ' Slurry temperature T (deg C)
    JacketTempC     AS DOUBLE  ' Cooling jacket coolant temperature
    TargetTempC     AS DOUBLE  ' Programmed cubic cooling setpoint
    
    ' Solution Thermodynamics
    SoluteConcKgKg  AS DOUBLE  ' Dissolved solute concentration C
    SolubilityCStar AS DOUBLE  ' Equilibrium solubility C*(T)
    SupersaturationSigma AS DOUBLE ' Driving force sigma = (C - C*) / C*
    MszwLimitSigma  AS DOUBLE  ' Metastable zone boundary (e.g. 0.08)
    
    ' Population Balance Moments
    MomentMu0       AS DOUBLE  ' Total number of crystals (# / kg)
    MomentMu1       AS DOUBLE  ' Total cumulative length (microns / kg)
    MomentMu2       AS DOUBLE  ' Total crystal surface area (microns^2 / kg)
    MomentMu3       AS DOUBLE  ' Total crystal volume (microns^3 / kg)
    MeanSizeD50Um   AS DOUBLE  ' Number-average crystal size d50 (microns)
    CrystalMassKg   AS DOUBLE  ' Total crystalline solid mass
    
    ' Kinetics
    NucleationRateB AS DOUBLE  ' Birth rate of nuclei (# / (kg * s))
    GrowthRateG     AS DOUBLE  ' Linear growth velocity (microns / s)
    CrashNucleationAlarm AS INTEGER ' 1 = Exceeded MSZW; fines penalty
END TYPE

' InitializeBatchCrystallizer: Seeds batch with initial crystal mass
SUB InitializeBatchCrystallizer(bc AS BatchCrystallizerState)
    bc.BatchTimeSec = 0.0
    bc.BatchDurationSec = 7200.0   ' 2-hour controlled batch
    bc.SlurryTempC = 65.0          ' Initial hot dissolution state
    bc.JacketTempC = 64.5
    bc.TargetTempC = 65.0
    
    ' Solubility model: C*(T) = 0.12 + 0.0035 * T + 0.00004 * T^2
    bc.SolubilityCStar = 0.12 + 0.0035 * 65.0 + 0.00004 * 65.0 * 65.0 ' ~0.516 kg/kg
    bc.SoluteConcKgKg = bc.SolubilityCStar ' Saturated at start
    bc.SupersaturationSigma = 0.0
    bc.MszwLimitSigma = 0.06       ' 6% relative supersaturation limit
    
    ' Seed crystals (100 kg batch seeded with 1 kg of 120 micron seeds)
    bc.MomentMu0 = 5.0E6           ' 5 million seed particles
    bc.MomentMu1 = 6.0E8           ' Mean size 120 microns
    bc.MomentMu2 = 9.0E10
    bc.MomentMu3 = 1.5E13
    bc.MeanSizeD50Um = 120.0
    bc.CrystalMassKg = 1.0
    
    bc.NucleationRateB = 0.0
    bc.GrowthRateG = 0.0
    bc.CrashNucleationAlarm = 0
END SUB

' StepBatchCrystallizerEuler: Advances moment equations and cooling curve
SUB StepBatchCrystallizerEuler(bc AS BatchCrystallizerState, dtSec AS DOUBLE)
    IF dtSec <= 0.0 THEN EXIT SUB
    
    bc.BatchTimeSec = bc.BatchTimeSec + dtSec
    
    ' 1. Programmed Mullin-Nyvlt Cubic Cooling Trajectory:
    ' T(t) = T_0 - (T_0 - T_final) * (t / t_batch)^3
    DIM tauFrac AS DOUBLE : tauFrac = bc.BatchTimeSec / bc.BatchDurationSec
    IF tauFrac > 1.0 THEN tauFrac = 1.0
    bc.TargetTempC = 65.0 - (65.0 - 20.0) * tauFrac * tauFrac * tauFrac
    
    ' Slurry temperature tracks jacket cooling with thermal lag (tau = 60 sec)
    bc.SlurryTempC = bc.SlurryTempC + ((bc.TargetTempC - bc.SlurryTempC) / 60.0) * dtSec
    
    ' 2. Equilibrium Solubility: C*(T)
    bc.SolubilityCStar = 0.12 + 0.0035 * bc.SlurryTempC + 0.00004 * bc.SlurryTempC * bc.SlurryTempC
    
    ' 3. Relative Supersaturation: sigma = (C - C*) / C*
    IF bc.SoluteConcKgKg > bc.SolubilityCStar THEN
        bc.SupersaturationSigma = (bc.SoluteConcKgKg - bc.SolubilityCStar) / bc.SolubilityCStar
    ELSE
        bc.SupersaturationSigma = 0.0
    END IF
    
    ' 4. Metastable Zone Width (MSZW) Supervision
    IF bc.SupersaturationSigma > bc.MszwLimitSigma THEN
        bc.CrashNucleationAlarm = 1
        ' Aggressive primary nucleation burst (fines generation)
        bc.NucleationRateB = 2.5E8 * (bc.SupersaturationSigma - bc.MszwLimitSigma)
    ELSE
        bc.CrashNucleationAlarm = 0
        ' Controlled secondary nucleation: B = k_b * sigma^1.5 * M_T
        bc.NucleationRateB = 1.2E6 * SQR(bc.SupersaturationSigma * bc.SupersaturationSigma * bc.SupersaturationSigma) * bc.CrystalMassKg
    END IF
    
    ' 5. Crystal Linear Growth Rate: G = k_g * sigma (microns / sec)
    bc.GrowthRateG = 0.45 * bc.SupersaturationSigma
    
    ' 6. Method of Moments Ordinary Differential Equations:
    ' d(mu0)/dt = B
    ' d(mu1)/dt = G * mu0
    ' d(mu2)/dt = 2 * G * mu1
    ' d(mu3)/dt = 3 * G * mu2
    bc.MomentMu0 = bc.MomentMu0 + bc.NucleationRateB * dtSec
    bc.MomentMu1 = bc.MomentMu1 + (bc.GrowthRateG * bc.MomentMu0) * dtSec
    bc.MomentMu2 = bc.MomentMu2 + (2.0 * bc.GrowthRateG * bc.MomentMu1) * dtSec
    bc.MomentMu3 = bc.MomentMu3 + (3.0 * bc.GrowthRateG * bc.MomentMu2) * dtSec
    
    ' 7. Mass Deposition & Solute Depletion:
    ' Solid density rho_c approx 1.35 g/cm^3 = 1.35E-12 kg/micron^3
    DIM dMassKg AS DOUBLE : dMassKg = (3.0 * bc.GrowthRateG * bc.MomentMu2) * 1.35E-12 * dtSec
    bc.CrystalMassKg = bc.CrystalMassKg + dMassKg
    bc.SoluteConcKgKg = bc.SoluteConcKgKg - dMassKg / 100.0 ' 100 kg solution basis
    IF bc.SoluteConcKgKg < 0.05 THEN bc.SoluteConcKgKg = 0.05
    
    ' 8. Mean Size Calculation: d50 = mu1 / mu0
    IF bc.MomentMu0 > 1.0 THEN
        bc.MeanSizeD50Um = bc.MomentMu1 / bc.MomentMu0
    END IF
END SUB
