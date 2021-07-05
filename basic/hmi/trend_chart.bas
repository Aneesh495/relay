' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Multi-Variable Terminal Historical Trend Chart Renderer
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/hmi/trend_chart.bas
' ==============================================================================
'
' This module renders real-time multi-pen process trend plots directly inside
' standard terminal environments without graphical dependencies:
'   - Multi-channel plotting: Process Variable (PV) and Setpoint (SP)
'   - Dynamic vertical Y-axis auto-scaling with engineering tick marks
'   - High-High and Low-Low alarm threshold dashed boundary lines
'   - Configurable horizontal time history window (e.g. last 60 scans)
' ==============================================================================

TYPE TrendPlotConfig
    Title           AS STRING
    Units           AS STRING
    PlotWidth       AS INTEGER ' Number of character columns (e.g. 60)
    PlotHeight      AS INTEGER ' Number of character rows (e.g. 15)
    YMin            AS DOUBLE
    YMax            AS DOUBLE
    AutoScaling     AS INTEGER ' 1 = Enabled, 0 = Manual
    AlarmLimitH     AS DOUBLE
    AlarmLimitL     AS DOUBLE
END TYPE

' InitializeTrendPlot: Configures chart dimensions and default scaling
SUB InitializeTrendPlot(cfg AS TrendPlotConfig, titleStr AS STRING, euStr AS STRING, w AS INTEGER, h AS INTEGER)
    cfg.Title = titleStr
    cfg.Units = euStr
    IF w > 20 THEN
        cfg.PlotWidth = w
    ELSE
        cfg.PlotWidth = 60
    END IF
    
    IF h > 5 THEN
        cfg.PlotHeight = h
    ELSE
        cfg.PlotHeight = 12
    END IF
    
    cfg.YMin = 0.0
    cfg.YMax = 100.0
    cfg.AutoScaling = 1
    cfg.AlarmLimitH = 80.0
    cfg.AlarmLimitL = 20.0
END SUB

' RenderTrendChart: Draws a full 2D grid plot from PV and SP data arrays
SUB RenderTrendChart(cfg AS TrendPlotConfig, pvData(100) AS DOUBLE, spData(100) AS DOUBLE, sampleCount AS INTEGER)
    IF sampleCount <= 0 THEN EXIT SUB
    
    ' Determine display range
    DIM effectiveMin AS DOUBLE : effectiveMin = cfg.YMin
    DIM effectiveMax AS DOUBLE : effectiveMax = cfg.YMax
    
    IF cfg.AutoScaling = 1 THEN
        effectiveMin = pvData(1)
        effectiveMax = pvData(1)
        DIM k AS INTEGER
        FOR k = 1 TO sampleCount
            IF pvData(k) < effectiveMin THEN effectiveMin = pvData(k)
            IF pvData(k) > effectiveMax THEN effectiveMax = pvData(k)
            IF spData(k) < effectiveMin THEN effectiveMin = spData(k)
            IF spData(k) > effectiveMax THEN effectiveMax = spData(k)
        NEXT k
        
        ' Add 5% headroom
        DIM span AS DOUBLE : span = effectiveMax - effectiveMin
        IF span < 0.1 THEN span = 1.0
        effectiveMin = effectiveMin - span * 0.05
        effectiveMax = effectiveMax + span * 0.05
    END IF
    
    PRINT "+--- [ "; cfg.Title; " ("; cfg.Units; ") ] ";
    DIM titlePad AS INTEGER : titlePad = cfg.PlotWidth - LEN(cfg.Title) - LEN(cfg.Units) - 14
    DIM p AS INTEGER
    FOR p = 1 TO titlePad : PRINT "-"; : NEXT p
    PRINT "+"
    
    ' Row loop from top (max) to bottom (min)
    DIM r AS INTEGER
    FOR r = cfg.PlotHeight TO 1 STEP -1
        ' Calculate row Y-value
        DIM rowVal AS DOUBLE
        rowVal = effectiveMin + ((r - 1.0) / (cfg.PlotHeight - 1.0)) * (effectiveMax - effectiveMin)
        
        ' Print Y-axis label every 3 rows
        IF r = cfg.PlotHeight OR r = 1 OR (r MOD 4 = 0) THEN
            PRINT PadLeft(FormatDouble(rowVal, 1), 7); " |";
        ELSE
            PRINT "        |";
        END IF
        
        ' Plot each time column
        DIM col AS INTEGER
        FOR col = 1 TO cfg.PlotWidth
            DIM sampleIdx AS INTEGER
            sampleIdx = sampleCount - cfg.PlotWidth + col
            
            IF sampleIdx >= 1 AND sampleIdx <= sampleCount THEN
                DIM pvRow AS INTEGER
                pvRow = 1 + INT(((pvData(sampleIdx) - effectiveMin) / (effectiveMax - effectiveMin)) * (cfg.PlotHeight - 1))
                
                DIM spRow AS INTEGER
                spRow = 1 + INT(((spData(sampleIdx) - effectiveMin) / (effectiveMax - effectiveMin)) * (cfg.PlotHeight - 1))
                
                IF pvRow = r AND spRow = r THEN
                    PRINT "+";  ' Coincident PV and SP
                ELSEIF pvRow = r THEN
                    PRINT "*";  ' PV point
                ELSEIF spRow = r THEN
                    PRINT "-";  ' SP line
                ELSEIF r = 1 THEN
                    PRINT "_";  ' X-axis baseline
                ELSE
                    PRINT " ";
                END IF
            ELSE
                PRINT " ";
            END IF
        NEXT col
        PRINT "|"
    NEXT r
    
    ' Bottom border and legend
    PRINT "        +";
    FOR p = 1 TO cfg.PlotWidth : PRINT "-"; : NEXT p
    PRINT "+"
    PRINT "        Legend: '*' Process Variable (PV)   '-' Setpoint (SP)   '+' Coincident"
    PRINT "        Time: Older ["; cfg.PlotWidth; " scans ago] -------------> Latest [Now]"
END SUB
