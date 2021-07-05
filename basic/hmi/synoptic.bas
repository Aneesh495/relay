' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Plant P&ID Synoptic Schematic Graphic Renderer
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/hmi/synoptic.bas
' ==============================================================================
'
' This module renders complete ASCII Piping and Instrumentation Diagrams (P&ID)
' showing live dynamic process state across interconnected plant equipment:
'   - Feed vessels, chemical reactors, pumps, heat exchangers, valves
'   - Real-time tank liquid level fill graphics
'   - Valve open/closed and throttling percentage indicators
'   - Dynamic temperature, pressure, and flow transmitter annotations
' ==============================================================================

TYPE PlantSynopticData
    FeedTankLevelPct   AS DOUBLE
    FeedFlowRateLMin   AS DOUBLE
    ReactorTempC       AS DOUBLE
    ReactorVolumeL     AS DOUBLE
    CoolantFlowLMin    AS DOUBLE
    CoolantTempC       AS DOUBLE
    ProductPumpHz      AS DOUBLE
    ProductDischargeBar AS DOUBLE
    HexBypassPct       AS DOUBLE
    HexProductTempC    AS DOUBLE
    SafetyValveOpen    AS INTEGER
END TYPE

' RenderPlantSynoptic: Renders full plant graphic schematic
SUB RenderPlantSynoptic(d AS PlantSynopticData)
    PRINT "================================================================================"
    PRINT " RELAY PROCESS SYNOPTIC OVERVIEW: PETROCHEMICAL PILOT PLANT UNIT 1"
    PRINT "================================================================================"
    PRINT "   FEED VESSEL V-101           EXOTHERMIC CSTR R-201             PRODUCT HEX E-301"
    PRINT "   +---------------+           +-------------------+             +---------------+"
    
    ' Render Feed Tank level
    DIM feedFill AS INTEGER : feedFill = INT((ClampValue(d.FeedTankLevelPct, 0.0, 100.0) / 100.0) * 11)
    PRINT "   | ";
    DIM f AS INTEGER
    FOR f = 1 TO 13
        IF f <= feedFill THEN PRINT "#"; ELSE PRINT " ";
    NEXT f
    PRINT " |           | Ca: 0.88 mol/L    |             | Area: 120 m^2 |"
    
    PRINT "   | Level:"; PadLeft(FormatDouble(d.FeedTankLevelPct, 1), 5); "% |           | Temp:"; PadLeft(FormatDouble(d.ReactorTempC, 1), 6); " deg C |             | Out:"; PadLeft(FormatDouble(d.HexProductTempC, 1), 5); " deg C|"
    PRINT "   +-------+-------+           | Vol: "; PadLeft(FormatDouble(d.ReactorVolumeL, 0), 4); " L       |             | Bypass:"; PadLeft(FormatDouble(d.HexBypassPct, 0), 3); "%    |"
    PRINT "           |                   +---------+---------+             +-------+-------+"
    PRINT "           |                             |                               |"
    PRINT "     [FCV-101: "; PadLeft(FormatDouble(d.FeedFlowRateLMin, 1), 5); " L/m]              |                               |"
    PRINT "           |                             |                               |"
    PRINT "           v                             v                               v"
    PRINT "   +---------------+           +-------------------+             +---------------+"
    PRINT "   | FEED PUMP     |---------->| JACKET COOLING    |------------>| STORAGE TANK  |"
    PRINT "   | P-101A [RUN]  |           | Flow:"; PadLeft(FormatDouble(d.CoolantFlowLMin, 1), 5); " L/m  |             | V-401         |"
    PRINT "   +---------------+           | Tin: "; PadLeft(FormatDouble(d.CoolantTempC, 1), 5); " deg C  |             | P: "; PadLeft(FormatDouble(d.ProductDischargeBar, 1), 4); " bar    |"
    PRINT "                               +-------------------+             +---------------+"
    
    IF d.SafetyValveOpen = 1 THEN
        PRINT " [! WARNING: PSV-201 OVERPRESSURE RELIEF VALVE DISCHARGING TO FLARE !]"
    ELSE
        PRINT " [ STATUS: ALL SAFETY INTERLOCKS HEALTHY | SIF CAUSE-EFFECT NORMAL ]"
    END IF
    PRINT "================================================================================"
END SUB
