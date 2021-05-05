' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Multi-Level Limit Monitoring & Hysteresis Deadbands
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/alarms/limit_check.bas
' ==============================================================================
'
' This module implements multi-level analog threshold monitoring (LL, L, H, HH)
' with directional hysteresis deadbands to eliminate alarm chattering.
' ==============================================================================

CONST LIMIT_TYPE_LOW_LOW   = 0
CONST LIMIT_TYPE_LOW       = 1
CONST LIMIT_TYPE_HIGH      = 2
CONST LIMIT_TYPE_HIGH_HIGH = 3

' MultiLevelAlarmConfig: Holds 4-level thresholds and shared hysteresis
TYPE MultiLevelAlarmConfig
    LimitLL     AS DOUBLE   ' Low-Low Emergency Trip
    LimitL      AS DOUBLE   ' Low Warning
    LimitH      AS DOUBLE   ' High Warning
    LimitHH     AS DOUBLE   ' High-High Emergency Trip
    Hysteresis  AS DOUBLE   ' Deadband required to clear trip

    ActiveLL    AS INTEGER  ' 1 if actively tripped
    ActiveL     AS INTEGER  ' 1 if actively tripped
    ActiveH     AS INTEGER  ' 1 if actively tripped
    ActiveHH    AS INTEGER  ' 1 if actively tripped
END TYPE

' InitializeMultiLevelLimits: Configures 4-level thresholds
SUB InitializeMultiLevelLimits(cfg AS MultiLevelAlarmConfig, ll AS DOUBLE, l AS DOUBLE, h AS DOUBLE, hh AS DOUBLE, hyst AS DOUBLE)
    cfg.LimitLL = ll
    cfg.LimitL = l
    cfg.LimitH = h
    cfg.LimitHH = hh
    cfg.Hysteresis = hyst > 0.0 ? hyst : 0.5
    cfg.ActiveLL = 0
    cfg.ActiveL = 0
    cfg.ActiveH = 0
    cfg.ActiveHH = 0
END SUB

' EvaluateMultiLevelLimits: Evaluates current process variable against all 4 levels
SUB EvaluateMultiLevelLimits(cfg AS MultiLevelAlarmConfig, pv AS DOUBLE)
    ' High-High (HH) Evaluation with Hysteresis
    IF cfg.ActiveHH = 0 THEN
        IF pv >= cfg.LimitHH THEN cfg.ActiveHH = 1
    ELSE
        IF pv <= (cfg.LimitHH - cfg.Hysteresis) THEN cfg.ActiveHH = 0
    END IF

    ' High (H) Evaluation with Hysteresis
    IF cfg.ActiveH = 0 THEN
        IF pv >= cfg.LimitH THEN cfg.ActiveH = 1
    ELSE
        IF pv <= (cfg.LimitH - cfg.Hysteresis) THEN cfg.ActiveH = 0
    END IF

    ' Low (L) Evaluation with Hysteresis
    IF cfg.ActiveL = 0 THEN
        IF pv <= cfg.LimitL THEN cfg.ActiveL = 1
    ELSE
        IF pv >= (cfg.LimitL + cfg.Hysteresis) THEN cfg.ActiveL = 0
    END IF

    ' Low-Low (LL) Evaluation with Hysteresis
    IF cfg.ActiveLL = 0 THEN
        IF pv <= cfg.LimitLL THEN cfg.ActiveLL = 1
    ELSE
        IF pv >= (cfg.LimitLL + cfg.Hysteresis) THEN cfg.ActiveLL = 0
    END IF
END SUB
