' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' IEC 61131-3 Standard Industrial Function Blocks: Edge Detection
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/iec61131/edge_detect.bas
' ==============================================================================
'
' This module implements the standard IEC 61131-3 edge detection blocks:
'   - R_TRIG: Rising Edge Detector (outputs 1 for exactly 1 scan on 0 -> 1)
'   - F_TRIG: Falling Edge Detector (outputs 1 for exactly 1 scan on 1 -> 0)
' ==============================================================================

TYPE RTrigDetector
    CLK             AS INTEGER ' Input clock / signal
    Q               AS INTEGER ' Single-scan pulse on rising transition
    M               AS INTEGER ' Internal memory of prior state
END TYPE

TYPE FTrigDetector
    CLK             AS INTEGER ' Input clock / signal
    Q               AS INTEGER ' Single-scan pulse on falling transition
    M               AS INTEGER ' Internal memory of prior state
END TYPE

' ExecuteRTrig: Rising edge evaluation
SUB ExecuteRTrig(trig AS RTrigDetector)
    IF trig.CLK = 1 AND trig.M = 0 THEN
        trig.Q = 1
    ELSE
        trig.Q = 0
    END IF
    trig.M = trig.CLK
END SUB

' ExecuteFTrig: Falling edge evaluation
SUB ExecuteFTrig(trig AS FTrigDetector)
    IF trig.CLK = 0 AND trig.M = 1 THEN
        trig.Q = 1
    ELSE
        trig.Q = 0
    END IF
    trig.M = trig.CLK
END SUB
