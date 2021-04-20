' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Åström-Hägglund Relay Feedback Auto-Tuning Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/autotuner.bas
' ==============================================================================
'
' This module implements the closed-loop relay feedback auto-tuning method
' developed by Karl Johan Åström and Tore Hägglund. It induces a controlled
' limit cycle oscillation, measures ultimate gain Ku and ultimate period Tu,
' and synthesizes optimal ISA PID tuning parameters.
' ==============================================================================

CONST TUNER_STATE_IDLE       = 0
CONST TUNER_STATE_RELAY_POS  = 1
CONST TUNER_STATE_RELAY_NEG  = 2
CONST TUNER_STATE_COMPLETED  = 3
CONST TUNER_STATE_FAILED     = 4

' AutoTunerState: Internal memory for limit cycle identification
TYPE AutoTunerState
    State           AS INTEGER  ' IDLE, POS, NEG, COMPLETED, FAILED
    Setpoint        AS DOUBLE   ' Process baseline setpoint
    RelayStep       AS DOUBLE   ' Output step perturbation amplitude d (e.g. 5.0%)
    Hysteresis      AS DOUBLE   ' Noise suppression hysteresis deadband

    BaseOutput      AS DOUBLE   ' Nominal steady-state output u0
    CommandOutput   AS DOUBLE   ' Real-time output commanded to valve

    CycleCount      AS INTEGER  ' Number of zero-crossing cycles observed
    TargetCycles    AS INTEGER  ' Number of cycles required for convergence (e.g. 3)

    PeakHigh        AS DOUBLE   ' Maximum process value in current oscillation
    PeakLow         AS DOUBLE   ' Minimum process value in current oscillation
    SumAmplitude    AS DOUBLE   ' Accumulated peak-to-peak amplitudes
    SumPeriodSec    AS DOUBLE   ' Accumulated cycle duration times

    LastCrossTimeSec AS DOUBLE  ' Timestamp of preceding zero-crossing
    ElapsedSec      AS DOUBLE   ' Total elapsed tuning time

    UltimateGainKu  AS DOUBLE   ' Identified critical gain Ku = 4*d / (pi*a)
    UltimatePeriodTu AS DOUBLE  ' Identified critical oscillation period Tu (sec)

    ' Resulting Synthesized PID Parameters
    TunedKp         AS DOUBLE
    TunedTi         AS DOUBLE
    TunedTd         AS DOUBLE
END TYPE

' InitializeAutoTuner: Configures the auto-tuning session
SUB InitializeAutoTuner(tuner AS AutoTunerState, sp AS DOUBLE, baseOp AS DOUBLE, stepSize AS DOUBLE, hyst AS DOUBLE)
    tuner.State = TUNER_STATE_RELAY_POS
    tuner.Setpoint = sp
    tuner.RelayStep = stepSize > 0.0 ? stepSize : 5.0
    tuner.Hysteresis = hyst > 0.0 ? hyst : 0.2
    tuner.BaseOutput = baseOp
    tuner.CommandOutput = baseOp + tuner.RelayStep

    tuner.CycleCount = 0
    tuner.TargetCycles = 3
    tuner.PeakHigh = sp
    tuner.PeakLow = sp
    tuner.SumAmplitude = 0.0
    tuner.SumPeriodSec = 0.0
    tuner.LastCrossTimeSec = 0.0
    tuner.ElapsedSec = 0.0

    tuner.UltimateGainKu = 0.0
    tuner.UltimatePeriodTu = 0.0
    tuner.TunedKp = 0.0
    tuner.TunedTi = 0.0
    tuner.TunedTd = 0.0
END SUB

' UpdateAutoTuner: Advances limit cycle detection by one execution sample
SUB UpdateAutoTuner(tuner AS AutoTunerState, pv AS DOUBLE, currentClockSec AS DOUBLE)
    IF tuner.State = TUNER_STATE_COMPLETED OR tuner.State = TUNER_STATE_IDLE THEN
        EXIT SUB
    END IF

    ' Track extreme excursion peaks
    IF pv > tuner.PeakHigh THEN tuner.PeakHigh = pv
    IF pv < tuner.PeakLow THEN tuner.PeakLow = pv

    ' Relay State Machine with Hysteresis
    IF tuner.State = TUNER_STATE_RELAY_POS THEN
        ' Output is positive step. Watch for PV to exceed SP + hysteresis
        IF pv > (tuner.Setpoint + tuner.Hysteresis) THEN
            ' Switch relay to negative step
            tuner.State = TUNER_STATE_RELAY_NEG
            tuner.CommandOutput = tuner.BaseOutput - tuner.RelayStep

            ' Record half-cycle timing
            IF tuner.LastCrossTimeSec > 0.0 THEN
                DIM halfPeriod AS DOUBLE
                halfPeriod = currentClockSec - tuner.LastCrossTimeSec
                tuner.SumPeriodSec = tuner.SumPeriodSec + halfPeriod * 2.0
                DIM amp AS DOUBLE : amp = (tuner.PeakHigh - tuner.PeakLow) * 0.5
                tuner.SumAmplitude = tuner.SumAmplitude + amp
                tuner.CycleCount = tuner.CycleCount + 1

                tuner.PeakHigh = pv
                tuner.PeakLow = pv
            END IF
            tuner.LastCrossTimeSec = currentClockSec
        END IF

    ELSEIF tuner.State = TUNER_STATE_RELAY_NEG THEN
        ' Output is negative step. Watch for PV to drop below SP - hysteresis
        IF pv < (tuner.Setpoint - tuner.Hysteresis) THEN
            ' Switch relay to positive step
            tuner.State = TUNER_STATE_RELAY_POS
            tuner.CommandOutput = tuner.BaseOutput + tuner.RelayStep

            IF tuner.LastCrossTimeSec > 0.0 THEN
                DIM halfPeriodNeg AS DOUBLE
                halfPeriodNeg = currentClockSec - tuner.LastCrossTimeSec
                tuner.SumPeriodSec = tuner.SumPeriodSec + halfPeriodNeg * 2.0
                DIM ampNeg AS DOUBLE : ampNeg = (tuner.PeakHigh - tuner.PeakLow) * 0.5
                tuner.SumAmplitude = tuner.SumAmplitude + ampNeg
                tuner.CycleCount = tuner.CycleCount + 1

                tuner.PeakHigh = pv
                tuner.PeakLow = pv
            END IF
            tuner.LastCrossTimeSec = currentClockSec
        END IF
    END IF

    ' Check if target cycles completed
    IF tuner.CycleCount >= tuner.TargetCycles THEN
        DIM avgAmp AS DOUBLE : avgAmp = tuner.SumAmplitude / tuner.CycleCount
        DIM avgPeriod AS DOUBLE : avgPeriod = tuner.SumPeriodSec / tuner.CycleCount

        IF avgAmp > 1.0E-6 AND avgPeriod > 0.0 THEN
            ' Describing function formula: Ku = (4 * d) / (pi * a)
            tuner.UltimateGainKu = (4.0 * tuner.RelayStep) / (MATH_PI * avgAmp)
            tuner.UltimatePeriodTu = avgPeriod

            ' Synthesize Tyreus-Luyben Tuning Rules (conservative industrial standard):
            ' Kp = 0.45 * Ku
            ' Ti = 2.2 * Tu
            ' Td = Tu / 6.3
            tuner.TunedKp = 0.45 * tuner.UltimateGainKu
            tuner.TunedTi = 2.2 * tuner.UltimatePeriodTu
            tuner.TunedTd = tuner.UltimatePeriodTu / 6.3

            tuner.State = TUNER_STATE_COMPLETED
            tuner.CommandOutput = tuner.BaseOutput
        ELSE
            tuner.State = TUNER_STATE_FAILED
        END IF
    END IF
END SUB
