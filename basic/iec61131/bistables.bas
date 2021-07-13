' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' IEC 61131-3 Standard Industrial Function Blocks: Bistables & Semaphores
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/iec61131/bistables.bas
' ==============================================================================
'
' This module implements the standard IEC 61131-3 bistable memory blocks:
'   - SR:   Set-Dominant Bistable Latch (S1 takes precedence over R)
'   - RS:   Reset-Dominant Bistable Latch (R1 takes precedence over S)
'   - SEMA: Software Binary Semaphore for mutual exclusion of field devices
' ==============================================================================

TYPE SrBistable
    S1              AS INTEGER ' Dominant set input
    R               AS INTEGER ' Reset input
    Q1              AS INTEGER ' Latched output state
END TYPE

TYPE RsBistable
    S               AS INTEGER ' Set input
    R1              AS INTEGER ' Dominant reset input
    Q1              AS INTEGER ' Latched output state
END TYPE

TYPE BinarySemaphore
    CLAIM           AS INTEGER ' Request lock input
    RELEASE         AS INTEGER ' Release lock input
    BUSY            AS INTEGER ' 1 = Locked, 0 = Available
END TYPE

' ExecuteSr: Evaluates Set-Dominant latch
' Logic: Q1 = S1 OR (Q1 AND NOT R)
SUB ExecuteSr(b AS SrBistable)
    IF b.S1 = 1 THEN
        b.Q1 = 1
    ELSEIF b.R = 1 THEN
        b.Q1 = 0
    END IF
END SUB

' ExecuteRs: Evaluates Reset-Dominant latch
' Logic: Q1 = NOT R1 AND (Q1 OR S)
SUB ExecuteRs(b AS RsBistable)
    IF b.R1 = 1 THEN
        b.Q1 = 0
    ELSEIF b.S = 1 THEN
        b.Q1 = 1
    END IF
END SUB

' ExecuteSema: Evaluates Binary Semaphore
SUB ExecuteSema(s AS BinarySemaphore)
    IF s.RELEASE = 1 THEN
        s.BUSY = 0
    ELSEIF s.CLAIM = 1 AND s.BUSY = 0 THEN
        s.BUSY = 1
    END IF
END SUB
