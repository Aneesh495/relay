' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Stoichiometric Ratio Blending & Cross-Limiting Combustion Control
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/ratio.bas
' ==============================================================================
'
' This module implements ratio control for continuous chemical blending
' and cross-limiting safety logic for industrial boilers and fired heaters.
' ==============================================================================

' RatioControllerState: Blending control configuration
TYPE RatioControllerState
    TargetRatio     AS DOUBLE  ' Nominal stoichiometric ratio R (e.g., 2.5 kg B per kg A)
    RatioTrim       AS DOUBLE  ' Analytical trim offset from downstream analyzer
    MinRatio        AS DOUBLE  ' Lower safety constraint on ratio
    MaxRatio        AS DOUBLE  ' Upper safety constraint on ratio
END TYPE

' CalculateControlledStreamSetpoint: Computes flow setpoint for secondary stream
FUNCTION CalculateControlledStreamSetpoint(state AS RatioControllerState, wildStreamFlow AS DOUBLE) AS DOUBLE
    IF wildStreamFlow <= 0.0 THEN RETURN 0.0

    DIM effectiveRatio AS DOUBLE
    effectiveRatio = state.TargetRatio + state.RatioTrim
    effectiveRatio = ClampValue(effectiveRatio, state.MinRatio, state.MaxRatio)

    RETURN wildStreamFlow * effectiveRatio
END FUNCTION

' CrossLimitingCombustionControl: Safety logic for fuel and combustion air flows.
' On load INCREASE: Combustion air MUST lead fuel (air rises first).
' On load DECREASE: Fuel MUST lead air (fuel drops first).
' This prevents fuel-rich hazardous combustion and catastrophic flame-outs.
SUB CrossLimitingCombustionControl(heatDemandOp AS DOUBLE, actualAirFlow AS DOUBLE, actualFuelFlow AS DOUBLE, _
                                   stoichAirRatio AS DOUBLE, excessAirMargin AS DOUBLE, _
                                   commandAirSp AS DOUBLE, commandFuelSp AS DOUBLE)
    ' Minimum permissible air for current fuel flow
    DIM minSafeAir AS DOUBLE
    minSafeAir = actualFuelFlow * stoichAirRatio * (1.0 + excessAirMargin)

    ' Maximum permissible fuel for current available air flow
    DIM maxSafeFuel AS DOUBLE
    DIM airDenom AS DOUBLE : airDenom = stoichAirRatio * (1.0 + excessAirMargin)
    IF airDenom > 0.0 THEN
        maxSafeFuel = actualAirFlow / airDenom
    ELSE
        maxSafeFuel = 0.0
    END IF

    ' Air setpoint is high-selected between firing demand and min safe air
    IF heatDemandOp > minSafeAir THEN
        commandAirSp = heatDemandOp
    ELSE
        commandAirSp = minSafeAir
    END IF

    ' Fuel setpoint is low-selected between firing demand and max safe fuel
    IF heatDemandOp < maxSafeFuel THEN
        commandFuelSp = heatDemandOp
    ELSE
        commandFuelSp = maxSafeFuel
    END IF
END SUB
