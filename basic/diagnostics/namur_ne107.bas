' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' NAMUR NE 107 Standard Field Device Diagnostic Status Engine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/diagnostics/namur_ne107.bas
' ==============================================================================
'
' This module implements the standardized device diagnostic signal structure
' defined by the international user association NAMUR in Recommendation NE 107:
'   - Standard Status Categories:
'       1. F: Failure (Red) - Device fault, signal invalid, immediate repair
'       2. C: Function Check (Orange) - Local loop test, calibration active
'       3. S: Out of Specification (Yellow) - Ambient or process envelope exceeded
'       4. M: Maintenance Required (Blue) - Predictive wear, schedule servicing
'       0. N: Normal (Green) - Valid measurement, zero active diagnostics
'   - Multi-device status aggregation and worst-case category propagation
' ==============================================================================

' NAMUR NE 107 Category Constants
CONST NE107_NORMAL              = 0 ' Green
CONST NE107_MAINTENANCE_REQ     = 1 ' Blue (M)
CONST NE107_OUT_OF_SPEC         = 2 ' Yellow (S)
CONST NE107_FUNCTION_CHECK      = 3 ' Orange (C)
CONST NE107_FAILURE             = 4 ' Red (F)

TYPE Ne107DeviceStatus
    DeviceTag       AS STRING
    PrimaryCategory AS INTEGER ' NE107_NORMAL, FAILURE, etc.
    
    ' Raw Diagnostic Bit Flags
    SensorFault     AS INTEGER ' Bit 0: Hardware transducer open/short
    ElectronicsFault AS INTEGER' Bit 1: Microcontroller or ADC failure
    SupplyVoltageLow AS INTEGER' Bit 2: Loop power supply < 18V DC
    TempExceeded    AS INTEGER ' Bit 3: Internal electronics temp > 85 C
    SimulationActive AS INTEGER' Bit 4: Technician forcing output
    CalibrationMode AS INTEGER ' Bit 5: Zero/span routine active
    WearCounterHigh AS INTEGER ' Bit 6: Valve stroke cycles > 1,000,000
    FoulingDetected AS INTEGER ' Bit 7: Flowmeter electrode coating
END TYPE

' MapNe107Status: Evaluates diagnostic bits and prioritizes primary category
SUB MapNe107Status(dev AS Ne107DeviceStatus)
    ' Priority 1 (Highest): Failure (F)
    IF dev.SensorFault = 1 OR dev.ElectronicsFault = 1 THEN
        dev.PrimaryCategory = NE107_FAILURE
        EXIT SUB
    END IF
    
    ' Priority 2: Function Check (C)
    IF dev.SimulationActive = 1 OR dev.CalibrationMode = 1 THEN
        dev.PrimaryCategory = NE107_FUNCTION_CHECK
        EXIT SUB
    END IF
    
    ' Priority 3: Out of Specification (S)
    IF dev.SupplyVoltageLow = 1 OR dev.TempExceeded = 1 THEN
        dev.PrimaryCategory = NE107_OUT_OF_SPEC
        EXIT SUB
    END IF
    
    ' Priority 4: Maintenance Required (M)
    IF dev.WearCounterHigh = 1 OR dev.FoulingDetected = 1 THEN
        dev.PrimaryCategory = NE107_MAINTENANCE_REQ
        EXIT SUB
    END IF
    
    dev.PrimaryCategory = NE107_NORMAL
END SUB

' GetNe107CategoryCode: Returns single-letter standard identifier
FUNCTION GetNe107CategoryCode(category AS INTEGER) AS STRING
    IF category = NE107_FAILURE THEN
        GetNe107CategoryCode = "F"
    ELSEIF category = NE107_FUNCTION_CHECK THEN
        GetNe107CategoryCode = "C"
    ELSEIF category = NE107_OUT_OF_SPEC THEN
        GetNe107CategoryCode = "S"
    ELSEIF category = NE107_MAINTENANCE_REQ THEN
        GetNe107CategoryCode = "M"
    ELSE
        GetNe107CategoryCode = "N"
    END IF
END FUNCTION
