' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' IEC 61131-3 Standard Industrial Function Blocks: Counters
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/iec61131/counters.bas
' ==============================================================================
'
' This module implements the standard IEC 61131-3 counter function blocks:
'   - CTU:  Up Counter with reset override
'   - CTD:  Down Counter with preset load
'   - CTUD: Bidirectional Up/Down Counter with independent boundary flags
' ==============================================================================

TYPE CtuCounter
    CU              AS INTEGER ' Count Up pulse input
    R               AS INTEGER ' Master reset input
    PV              AS INTEGER ' Preset value threshold
    Q               AS INTEGER ' Output flag (CV >= PV)
    CV              AS INTEGER ' Current count value
    LastCU          AS INTEGER
END TYPE

TYPE CtdCounter
    CD              AS INTEGER ' Count Down pulse input
    LD              AS INTEGER ' Load preset input
    PV              AS INTEGER ' Preset value
    Q               AS INTEGER ' Output flag (CV <= 0)
    CV              AS INTEGER ' Current count value
    LastCD          AS INTEGER
END TYPE

TYPE CtudCounter
    CU              AS INTEGER ' Count Up pulse
    CD              AS INTEGER ' Count Down pulse
    R               AS INTEGER ' Reset
    LD              AS INTEGER ' Load
    PV              AS INTEGER ' Preset value
    QU              AS INTEGER ' Up output (CV >= PV)
    QD              AS INTEGER ' Down output (CV <= 0)
    CV              AS INTEGER ' Current count value
    LastCU          AS INTEGER
    LastCD          AS INTEGER
END TYPE

' ExecuteCtu: Processes one cycle of IEC 61131-3 Up Counter
SUB ExecuteCtu(c AS CtuCounter)
    IF c.R = 1 THEN
        c.CV = 0
        c.Q = 0
    ELSE
        ' Detect rising edge on CU
        IF c.CU = 1 AND c.LastCU = 0 THEN
            IF c.CV < 32767 THEN c.CV = c.CV + 1
        END IF
        
        IF c.CV >= c.PV THEN
            c.Q = 1
        ELSE
            c.Q = 0
        END IF
    END IF
    c.LastCU = c.CU
END SUB

' ExecuteCtd: Processes one cycle of IEC 61131-3 Down Counter
SUB ExecuteCtd(c AS CtdCounter)
    IF c.LD = 1 THEN
        c.CV = c.PV
        c.Q = 0
    ELSE
        ' Detect rising edge on CD
        IF c.CD = 1 AND c.LastCD = 0 THEN
            IF c.CV > -32768 THEN c.CV = c.CV - 1
        END IF
        
        IF c.CV <= 0 THEN
            c.Q = 1
        ELSE
            c.Q = 0
        END IF
    END IF
    c.LastCD = c.CD
END SUB

' ExecuteCtud: Processes one cycle of Bidirectional Counter
SUB ExecuteCtud(c AS CtudCounter)
    IF c.R = 1 THEN
        c.CV = 0
    ELSEIF c.LD = 1 THEN
        c.CV = c.PV
    ELSE
        ' Count Up edge
        IF c.CU = 1 AND c.LastCU = 0 THEN
            IF c.CV < 32767 THEN c.CV = c.CV + 1
        END IF
        ' Count Down edge
        IF c.CD = 1 AND c.LastCD = 0 THEN
            IF c.CV > -32768 THEN c.CV = c.CV - 1
        END IF
    END IF
    
    IF c.CV >= c.PV THEN
        c.QU = 1
    ELSE
        c.QU = 0
    END IF
    
    IF c.CV <= 0 THEN
        c.QD = 1
    ELSE
        c.QD = 0
    END IF
    
    c.LastCU = c.CU
    c.LastCD = c.CD
END SUB
