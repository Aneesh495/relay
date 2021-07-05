' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' High-Performance ANSI Terminal Process Control Faceplates
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/hmi/faceplates.bas
' ==============================================================================
'
' This module implements standard industrial process control faceplates
' for display in ANSI VT100 / xterm color terminals:
'   - Standard ISA / EEMUA 191 visual hierarchy
'   - Multi-mode indication: AUTO (Automatic), MAN (Manual), CAS (Cascade)
'   - Horizontal and vertical bargraphs with SP, PV, and OP indicators
'   - Dynamic alarm limit trip marks (HH, H, L, LL)
' ==============================================================================

TYPE FaceplateView
    LoopTag         AS STRING
    Description     AS STRING
    Units           AS STRING
    ControlMode     AS STRING  ' "AUTO", "MAN", "CAS"
    
    SP              AS DOUBLE
    PV              AS DOUBLE
    OP              AS DOUBLE
    
    RangeMin        AS DOUBLE
    RangeMax        AS DOUBLE
    LimitLL         AS DOUBLE
    LimitL          AS DOUBLE
    LimitH          AS DOUBLE
    LimitHH         AS DOUBLE
    
    AlarmStatus     AS STRING  ' "NORMAL", "HIGH", "HI-HI", "LOW", "LO-LO"
END TYPE

' InitializeFaceplate: Configures default faceplate attributes
SUB InitializeFaceplate(fp AS FaceplateView, tag AS STRING, desc AS STRING, eu AS STRING, rMin AS DOUBLE, rMax AS DOUBLE)
    fp.LoopTag = tag
    fp.Description = desc
    fp.Units = eu
    fp.ControlMode = "AUTO"
    
    fp.RangeMin = rMin
    fp.RangeMax = rMax
    fp.SP = (rMin + rMax) * 0.5
    fp.PV = fp.SP
    fp.OP = 50.0
    
    fp.LimitLL = rMin + (rMax - rMin) * 0.10
    fp.LimitL  = rMin + (rMax - rMin) * 0.20
    fp.LimitH  = rMin + (rMax - rMin) * 0.80
    fp.LimitHH = rMin + (rMax - rMin) * 0.90
    fp.AlarmStatus = "NORMAL"
END SUB

' RenderProgressBar: Draws a 24-character textual progress bar [====|.....]
SUB RenderProgressBar(valPct AS DOUBLE, spPct AS DOUBLE, barWidth AS INTEGER)
    IF barWidth < 10 THEN barWidth = 24
    
    DIM fillCount AS INTEGER
    fillCount = INT((ClampValue(valPct, 0.0, 100.0) / 100.0) * barWidth)
    
    DIM spPos AS INTEGER
    spPos = INT((ClampValue(spPct, 0.0, 100.0) / 100.0) * barWidth)
    
    PRINT "[";
    DIM i AS INTEGER
    FOR i = 1 TO barWidth
        IF i = spPos THEN
            PRINT "|";
        ELSEIF i <= fillCount THEN
            PRINT "=";
        ELSE
            PRINT ".";
        END IF
    NEXT i
    PRINT "]";
END SUB

' RenderFaceplate: Draws full formatted faceplate card in terminal
SUB RenderFaceplate(fp AS FaceplateView)
    PRINT "+--------------------------------------------------------------+"
    PRINT "| LOOP: "; PadRight(fp.LoopTag, 10); "  "; PadRight(fp.Description, 26); " ["; fp.ControlMode; "] |"
    PRINT "+--------------------------------------------------------------+"
    
    ' Calculate percentages
    DIM span AS DOUBLE : span = fp.RangeMax - fp.RangeMin
    IF span <= 0.001 THEN span = 1.0
    
    DIM pvPct AS DOUBLE : pvPct = ((fp.PV - fp.RangeMin) / span) * 100.0
    DIM spPct AS DOUBLE : spPct = ((fp.SP - fp.RangeMin) / span) * 100.0
    
    PRINT "| PV: "; PadLeft(FormatDouble(fp.PV, 2), 8); " "; PadRight(fp.Units, 6); " ";
    RenderProgressBar(pvPct, spPct, 24)
    PRINT " "; PadLeft(FormatDouble(pvPct, 1), 5); "% |"
    
    PRINT "| SP: "; PadLeft(FormatDouble(fp.SP, 2), 8); " "; PadRight(fp.Units, 6); " ";
    RenderProgressBar(spPct, spPct, 24)
    PRINT " "; PadLeft(FormatDouble(spPct, 1), 5); "% |"
    
    PRINT "| OP: "; PadLeft(FormatDouble(fp.OP, 2), 8); " %      ";
    RenderProgressBar(fp.OP, fp.OP, 24)
    PRINT " "; PadLeft(FormatDouble(fp.OP, 1), 5); "% |"
    
    PRINT "+--------------------------------------------------------------+"
    PRINT "| ALARM: "; PadRight(fp.AlarmStatus, 12); " LL:"; FormatDouble(fp.LimitLL, 1); " L:"; FormatDouble(fp.LimitL, 1); " H:"; FormatDouble(fp.LimitH, 1); " HH:"; FormatDouble(fp.LimitHH, 1); " |"
    PRINT "+--------------------------------------------------------------+"
END SUB
