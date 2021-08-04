' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Microgrid Under-Frequency Load Shedding (UFLS) & ROCOF Protection Relay
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/power/load_shedding.bas
' ==============================================================================
'
' This module implements the IEEE / NERC standard multi-stage under-frequency
' load shedding (UFLS) and rate-of-change-of-frequency (ROCOF) protection:
'   - 4-Stage hierarchical priority feeder tripping to arrest frequency collapse
'   - Stage 1 (49.2 Hz): Non-essential commercial / auxiliary loads (10%)
'   - Stage 2 (49.0 Hz): Intermediate distribution feeders (15%)
'   - Stage 3 (48.8 Hz): Heavy industrial process loads (20%)
'   - Stage 4 (48.5 Hz): Islanding breaker trip / microgrid island mode
'   - Dynamic ROCOF df/dt trip gate for severe generation loss contingencies
' ==============================================================================

TYPE UflsRelayState
    GridFrequencyHz AS DOUBLE  ' Current electrical grid frequency (nominal 50.00 Hz)
    LastFrequencyHz AS DOUBLE
    RocofHzSec      AS DOUBLE  ' df/dt rate of change (Hz / sec)
    
    Stage1Tripped   AS INTEGER ' 49.2 Hz trip
    Stage2Tripped   AS INTEGER ' 49.0 Hz trip
    Stage3Tripped   AS INTEGER ' 48.8 Hz trip
    IslandedTripped AS INTEGER ' 48.5 Hz islanding trip
    
    TotalLoadShedMW AS DOUBLE  ' Aggregate load dropped
    RelayArmed      AS INTEGER ' 1 = Protection in service
END TYPE

' InitializeUflsRelay: Sets up standard 50 Hz microgrid protection
SUB InitializeUflsRelay(relay AS UflsRelayState)
    relay.GridFrequencyHz = 50.00
    relay.LastFrequencyHz = 50.00
    relay.RocofHzSec = 0.0
    
    relay.Stage1Tripped = 0
    relay.Stage2Tripped = 0
    relay.Stage3Tripped = 0
    relay.IslandedTripped = 0
    
    relay.TotalLoadShedMW = 0.0
    relay.RelayArmed = 1
END SUB

' StepUflsProtection: Evaluates frequency excursion and triggers trip stages
SUB StepUflsProtection(relay AS UflsRelayState, freqHz AS DOUBLE, dtSec AS DOUBLE)
    IF dtSec <= 0.0001 OR relay.RelayArmed = 0 THEN EXIT SUB
    
    relay.GridFrequencyHz = freqHz
    
    ' Calculate ROCOF df/dt
    relay.RocofHzSec = (relay.GridFrequencyHz - relay.LastFrequencyHz) / dtSec
    relay.LastFrequencyHz = relay.GridFrequencyHz
    
    ' Fast ROCOF trip: df/dt < -1.5 Hz/s indicates catastrophic generator loss
    IF relay.RocofHzSec < -1.5 THEN
        IF relay.Stage1Tripped = 0 THEN
            relay.Stage1Tripped = 1
            relay.TotalLoadShedMW = relay.TotalLoadShedMW + 12.0
            PRINT "[ROCOF FAST TRIP] Stage 1 triggered on df/dt:", relay.RocofHzSec, "Hz/s"
        END IF
    END IF
    
    ' Stage 1: 49.20 Hz (Drop 12 MW auxiliary load)
    IF relay.GridFrequencyHz <= 49.20 AND relay.Stage1Tripped = 0 THEN
        relay.Stage1Tripped = 1
        relay.TotalLoadShedMW = relay.TotalLoadShedMW + 12.0
        PRINT "[UFLS STAGE 1] Frequency dropped to"; relay.GridFrequencyHz; "Hz. Shed 12 MW."
    END IF
    
    ' Stage 2: 49.00 Hz (Drop 18 MW secondary distribution)
    IF relay.GridFrequencyHz <= 49.00 AND relay.Stage2Tripped = 0 THEN
        relay.Stage2Tripped = 1
        relay.TotalLoadShedMW = relay.TotalLoadShedMW + 18.0
        PRINT "[UFLS STAGE 2] Frequency dropped to"; relay.GridFrequencyHz; "Hz. Shed 18 MW."
    END IF
    
    ' Stage 3: 48.80 Hz (Drop 25 MW industrial loads)
    IF relay.GridFrequencyHz <= 48.80 AND relay.Stage3Tripped = 0 THEN
        relay.Stage3Tripped = 1
        relay.TotalLoadShedMW = relay.TotalLoadShedMW + 25.0
        PRINT "[UFLS STAGE 3] Frequency dropped to"; relay.GridFrequencyHz; "Hz. Shed 25 MW."
    END IF
    
    ' Stage 4: 48.50 Hz (Main Grid Intertie Separation / Islanding)
    IF relay.GridFrequencyHz <= 48.50 AND relay.IslandedTripped = 0 THEN
        relay.IslandedTripped = 1
        PRINT "[UFLS STAGE 4] Under-frequency Islanding! Main tie breaker opened at"; relay.GridFrequencyHz; "Hz"
    END IF
END SUB
