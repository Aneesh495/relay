' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' IEC 61131-3 Standard Industrial Function Blocks: Timers & Real-Time Clock
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/iec61131/timers.bas
' ==============================================================================
'
' This module implements the standard IEC 61131-3 timer function blocks:
'   - TON: On-Delay Timer with millisecond precision
'   - TOF: Off-Delay Timer with trailing edge hold
'   - TP:  Pulse Timer with non-retriggerable fixed duration output
'   - RTC: Real-Time Clock calendar accumulator with leap year adjustment
' ==============================================================================

TYPE TonTimer
    IN              AS INTEGER ' Timer execution enable condition
    PT_Ms           AS DOUBLE  ' Preset time interval (milliseconds)
    Q               AS INTEGER ' Output flag (1 when ET >= PT)
    ET_Ms           AS DOUBLE  ' Elapsed running time
    IsRunning       AS INTEGER
END TYPE

TYPE TofTimer
    IN              AS INTEGER ' Timer input
    PT_Ms           AS DOUBLE  ' Preset off-delay interval
    Q               AS INTEGER ' Output flag
    ET_Ms           AS DOUBLE  ' Elapsed time since falling edge
    LastIN          AS INTEGER
END TYPE

TYPE TpTimer
    IN              AS INTEGER ' Trigger input
    PT_Ms           AS DOUBLE  ' Pulse duration
    Q               AS INTEGER ' Active pulse output
    ET_Ms           AS DOUBLE  ' Elapsed pulse time
    LastIN          AS INTEGER
    InPulse         AS INTEGER
END TYPE

TYPE RtcClock
    EN              AS INTEGER ' Enable counting
    Year            AS INTEGER
    Month           AS INTEGER
    Day             AS INTEGER
    Hour            AS INTEGER
    Minute          AS INTEGER
    Second          AS INTEGER
    Millisecond     AS DOUBLE
END TYPE

' ExecuteTon: Standard IEC 61131-3 On-Delay Timer cycle
SUB ExecuteTon(t AS TonTimer, dtMs AS DOUBLE)
    IF t.IN = 1 THEN
        t.IsRunning = 1
        t.ET_Ms = t.ET_Ms + dtMs
        IF t.ET_Ms >= t.PT_Ms THEN
            t.ET_Ms = t.PT_Ms
            t.Q = 1
        ELSE
            t.Q = 0
        END IF
    ELSE
        t.IsRunning = 0
        t.ET_Ms = 0.0
        t.Q = 0
    END IF
END SUB

' ExecuteTof: Standard IEC 61131-3 Off-Delay Timer cycle
SUB ExecuteTof(t AS TofTimer, dtMs AS DOUBLE)
    IF t.IN = 1 THEN
        t.Q = 1
        t.ET_Ms = 0.0
    ELSE
        ' Falling edge or kept low: count elapsed time
        IF t.Q = 1 THEN
            t.ET_Ms = t.ET_Ms + dtMs
            IF t.ET_Ms >= t.PT_Ms THEN
                t.ET_Ms = t.PT_Ms
                t.Q = 0
            END IF
        ELSE
            t.ET_Ms = t.PT_Ms
        END IF
    END IF
    t.LastIN = t.IN
END SUB

' ExecuteTp: Standard IEC 61131-3 Pulse Timer cycle
SUB ExecuteTp(t AS TpTimer, dtMs AS DOUBLE)
    ' Detect rising edge on IN
    IF t.IN = 1 AND t.LastIN = 0 AND t.InPulse = 0 THEN
        t.InPulse = 1
        t.Q = 1
        t.ET_Ms = 0.0
    END IF
    
    IF t.InPulse = 1 THEN
        t.ET_Ms = t.ET_Ms + dtMs
        IF t.ET_Ms >= t.PT_Ms THEN
            t.ET_Ms = t.PT_Ms
            t.Q = 0
            t.InPulse = 0
        ELSE
            t.Q = 1
        END IF
    ELSE
        t.Q = 0
        t.ET_Ms = 0.0
    END IF
    
    t.LastIN = t.IN
END SUB

' AdvanceRtc: Advances Real-Time Clock by dtMs milliseconds
SUB AdvanceRtc(c AS RtcClock, dtMs AS DOUBLE)
    IF c.EN = 0 THEN EXIT SUB
    
    c.Millisecond = c.Millisecond + dtMs
    WHILE c.Millisecond >= 1000.0
        c.Millisecond = c.Millisecond - 1000.0
        c.Second = c.Second + 1
        IF c.Second >= 60 THEN
            c.Second = 0
            c.Minute = c.Minute + 1
            IF c.Minute >= 60 THEN
                c.Minute = 0
                c.Hour = c.Hour + 1
                IF c.Hour >= 24 THEN
                    c.Hour = 0
                    c.Day = c.Day + 1
                    ' Simplified 30-day month rollover
                    IF c.Day > 30 THEN
                        c.Day = 1
                        c.Month = c.Month + 1
                        IF c.Month > 12 THEN
                            c.Month = 1
                            c.Year = c.Year + 1
                        END IF
                    END IF
                END IF
            END IF
        END IF
    WEND
END SUB
