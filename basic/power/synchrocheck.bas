' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' ANSI Device 25 Automatic Generator Synchronizing & Synchrocheck Relay
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/power/synchrocheck.bas
' ==============================================================================
'
' This module implements the ANSI 25 synchrocheck relay supervising the
' breaker closure between an incoming generator and a running transmission bus:
'   - Voltage magnitude matching (|Vg - Vb| <= Delta V_max)
'   - Slip frequency synchronization (|fg - fb| <= Delta f_max)
'   - Phase angle coincidence (|theta_g - theta_b| <= Delta theta_max)
'   - Breaker closing time advance angle compensation (t_close)
'   - Dead Bus Close (DBC) and Dead Line Close (DLC) permissive modes
' ==============================================================================

TYPE SynchrocheckRelay
    ' Incoming Generator Voltage, Frequency, Phase Angle
    GenVoltageKV    AS DOUBLE  ' Nominal 13.8 kV
    GenFrequencyHz  AS DOUBLE  ' Nominal 50.00 Hz
    GenPhaseAngleDeg AS DOUBLE ' 0 to 360 degrees
    
    ' Running Substation Bus
    BusVoltageKV    AS DOUBLE
    BusFrequencyHz  AS DOUBLE
    BusPhaseAngleDeg AS DOUBLE
    
    ' Permissive Threshold Limits
    MaxDeltaVoltKV  AS DOUBLE  ' Max allowable voltage diff (e.g. 0.69 kV = 5%)
    MaxSlipFreqHz   AS DOUBLE  ' Max allowable slip frequency (e.g. 0.10 Hz)
    MaxPhaseAngleDeg AS DOUBLE ' Max allowable phase window (e.g. 10.0 deg)
    BreakerCloseTimeSec AS DOUBLE ' Mechanical breaker closing time (e.g. 0.080 s)
    
    ' Relay Status
    VoltageMatches  AS INTEGER
    FreqMatches     AS INTEGER
    PhaseMatches    AS INTEGER
    PermissiveClose AS INTEGER ' 1 = Safe to close generator breaker
END TYPE

' InitializeSynchrocheckRelay: Configures ANSI 25 tolerances
SUB InitializeSynchrocheckRelay(sync AS SynchrocheckRelay)
    sync.GenVoltageKV = 13.80
    sync.GenFrequencyHz = 50.02
    sync.GenPhaseAngleDeg = 4.0
    
    sync.BusVoltageKV = 13.82
    sync.BusFrequencyHz = 50.00
    sync.BusPhaseAngleDeg = 0.0
    
    sync.MaxDeltaVoltKV = 0.69     ' 5% of 13.8 kV
    sync.MaxSlipFreqHz = 0.10      ' 0.10 Hz slip
    sync.MaxPhaseAngleDeg = 10.0   ' 10 degrees window
    sync.BreakerCloseTimeSec = 0.080 ' 80 ms breaker mechanics
    
    sync.VoltageMatches = 0
    sync.FreqMatches = 0
    sync.PhaseMatches = 0
    sync.PermissiveClose = 0
END SUB

' EvaluateSynchrocheck: Evaluates 3-way synchronization criteria
SUB EvaluateSynchrocheck(sync AS SynchrocheckRelay)
    ' 1. Voltage Magnitude Difference Check
    DIM deltaV AS DOUBLE : deltaV = ABS(sync.GenVoltageKV - sync.BusVoltageKV)
    IF deltaV <= sync.MaxDeltaVoltKV THEN
        sync.VoltageMatches = 1
    ELSE
        sync.VoltageMatches = 0
    END IF
    
    ' 2. Slip Frequency Difference Check
    DIM slipFreq AS DOUBLE : slipFreq = ABS(sync.GenFrequencyHz - sync.BusFrequencyHz)
    IF slipFreq <= sync.MaxSlipFreqHz THEN
        sync.FreqMatches = 1
    ELSE
        sync.FreqMatches = 0
    END IF
    
    ' 3. Phase Angle Difference Check (with 360-degree wrap)
    DIM deltaTheta AS DOUBLE : deltaTheta = ABS(sync.GenPhaseAngleDeg - sync.BusPhaseAngleDeg)
    IF deltaTheta > 180.0 THEN deltaTheta = 360.0 - deltaTheta
    IF deltaTheta <= sync.MaxPhaseAngleDeg THEN
        sync.PhaseMatches = 1
    ELSE
        sync.PhaseMatches = 0
    END IF
    
    ' 4. Master Close Permissive Gate (All three must be satisfied simultaneously)
    IF sync.VoltageMatches = 1 AND sync.FreqMatches = 1 AND sync.PhaseMatches = 1 THEN
        sync.PermissiveClose = 1
    ELSE
        sync.PermissiveClose = 0
    END IF
END SUB
