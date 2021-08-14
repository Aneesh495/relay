' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Core User-Defined Types and System Record Definitions
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/common/types.bas
' ==============================================================================
'
' This module defines the foundational user-defined types (UDTs) and records
' utilized throughout the Relay process automation platform. All structures
' conform to international industrial automation standards, specifically:
'   - IEC 61131-3: Programmable controllers - Programming languages
'   - ISA-18.2: Management of Alarm Systems for the Process Industries
'   - ISA-88 (S88): Batch Control Architecture
'   - IEEE 754: Double-precision floating point representations
' ==============================================================================

' ------------------------------------------------------------------------------
' SECTION 1: SYSTEM CONSTANTS AND ENUMERATIONS
' ------------------------------------------------------------------------------

' Tag Classification Codes (IEC 61131-3 Elementary Types)
CONST TAG_TYPE_ANALOG_IN      = 0   ' 4-20mA or 0-10V Analog Input
CONST TAG_TYPE_ANALOG_OUT     = 1   ' 4-20mA Actuator Output
CONST TAG_TYPE_DISCRETE_IN    = 2   ' 24VDC Digital Field Input
CONST TAG_TYPE_DISCRETE_OUT   = 3   ' Relay / Solenoid Digital Output
CONST TAG_TYPE_CALCULATED     = 4   ' Synthetic Derived Math Expression
CONST TAG_TYPE_STRING         = 5   ' Serial or Diagnostic Text Payload

' Tag Data Quality Status Codes (OPC DA / Industrial Fieldbus Standard)
CONST QUALITY_BAD_NONSPECIFIC = 0   ' Sensor signal unresolvable
CONST QUALITY_BAD_COMM_FAIL   = 24  ' Fieldbus bus timeout or parity fault
CONST QUALITY_BAD_SENSOR_FAIL = 8   ' ADC wire-break or out-of-limits fault
CONST QUALITY_UNCERTAIN       = 64  ' Sub-optimal signal, degraded accuracy
CONST QUALITY_MANUAL_OVERRIDE = 96  ' Operator forced manual simulation
CONST QUALITY_GOOD            = 192 ' Verified valid within calibration span

' ISA-18.2 Alarm Severity Levels
CONST ALARM_SEV_DIAGNOSTIC    = 0   ' Informational telemetry notification
CONST ALARM_SEV_LOW           = 1   ' Operator advisory, no immediate risk
CONST ALARM_SEV_MEDIUM        = 2   ' Process deviation requiring action
CONST ALARM_SEV_HIGH          = 3   ' Critical limit, safety hazard pending
CONST ALARM_SEV_EMERGENCY     = 4   ' Safety trip imminent, immediate shutdown

' ISA-18.2 Alarm Operational States
CONST ALARM_STATE_NORMAL      = 0   ' Cleared, acknowledged, within band
CONST ALARM_STATE_UNACK       = 1   ' Active trip condition, awaiting ack
CONST ALARM_STATE_ACKED       = 2   ' Active condition acknowledged by operator
CONST ALARM_STATE_RTN_UNACK   = 3   ' Process returned to normal, unacknowledged
CONST ALARM_STATE_SHELVED     = 4   ' Temporarily suppressed by operator
CONST ALARM_STATE_SUPPRESSED  = 5   ' Suppressed by control logic interlock

' ISA-88 Batch Execution States
CONST BATCH_STATE_IDLE        = 0   ' Ready for recipe initialization
CONST BATCH_STATE_RUNNING     = 1   ' Active execution of recipe phases
CONST BATCH_STATE_PAUSING     = 2   ' Transitioning toward paused hold
CONST BATCH_STATE_PAUSED      = 3   ' Execution suspended at current step
CONST BATCH_STATE_HOLDING     = 4   ' Abnormal deviation hold sequence active
CONST BATCH_STATE_HELD        = 5   ' Safe state maintained during hold
CONST BATCH_STATE_RESTARTING  = 6   ' Resuming sequence toward active run
CONST BATCH_STATE_COMPLETING  = 7   ' Final flushing, discharge, post-checks
CONST BATCH_STATE_COMPLETED   = 8   ' Successful termination of recipe
CONST BATCH_STATE_ABORTING    = 9   ' Emergency abort shutdown in progress
CONST BATCH_STATE_ABORTED     = 10  ' Terminal fail-safe state after abort
CONST BATCH_STATE_STOPPING    = 11  ' Controlled shutdown sequence
CONST BATCH_STATE_STOPPED     = 12  ' Terminal idle state after stop

' Controller Operating Modes
CONST CTRL_MODE_MANUAL        = 0   ' Direct operator output manipulation
CONST CTRL_MODE_AUTO          = 1   ' Closed-loop PID setpoint regulation
CONST CTRL_MODE_CASCADE       = 2   ' Secondary loop setpoint driven by master
CONST CTRL_MODE_TRACKING      = 3   ' Bumpless tracking of downstream valve

' ------------------------------------------------------------------------------
' SECTION 2: DATA STRUCTURE RECORDS
' ------------------------------------------------------------------------------

' TagDefinition: Core database schema representing a single SCADA point
TYPE TagDefinition
    TagId           AS INTEGER  ' Unique numeric identifier
    TagName         AS STRING   ' ISA 5.1 Tag identifier (e.g., TT_101)
    TagType         AS INTEGER  ' Analog/Discrete/Calculated type code
    Quality         AS INTEGER  ' Operational quality flag (OPC DA standard)
    EuValue         AS DOUBLE   ' Process variable in engineering units
    RawValue        AS DOUBLE   ' Unscaled counts from ADC or fieldbus
    EuMin           AS DOUBLE   ' Engineering span zero (e.g., 0.0 deg C)
    EuMax           AS DOUBLE   ' Engineering span full-scale (e.g., 200.0)
    RawMin          AS DOUBLE   ' Raw count minimum (e.g., 0 or 4.0 mA)
    RawMax          AS DOUBLE   ' Raw count maximum (e.g., 65535 or 20.0 mA)
    DeadbandAbs     AS DOUBLE   ' Absolute change threshold to emit update
    DeadbandPct     AS DOUBLE   ' Percent-of-span change threshold
    LastEmittedVal  AS DOUBLE   ' Previous value stored in historian
    TimestampMs     AS DOUBLE   ' Epoch milliseconds of last sample
    IsSimulated     AS INTEGER  ' Boolean flag: 1 if driven by digital twin
    IsClamped       AS INTEGER  ' Boolean flag: 1 if clamped at span limits
END TYPE

' PidControllerState: Internal states, parameters, and tuning constants
TYPE PidControllerState
    LoopId          AS INTEGER  ' Unique loop index (e.g., TIC_101)
    Mode            AS INTEGER  ' MANUAL, AUTO, CASCADE, or TRACKING
    Setpoint        AS DOUBLE   ' Target process value (SP)
    ProcessVariable AS DOUBLE   ' Current measured variable (PV)
    ControlOutput   AS DOUBLE   ' Actuator output command 0.0 to 100.0% (OP)
    ManualOutput    AS DOUBLE   ' Stored manual valve position

    ' Tuning Constants
    Kp              AS DOUBLE   ' Proportional gain (dimensionless or %/EU)
    Ti              AS DOUBLE   ' Integral reset time (seconds per repeat)
    Td              AS DOUBLE   ' Derivative rate time (seconds)
    Alpha           AS DOUBLE   ' Derivative filter coefficient (typically 0.1)
    Beta            AS DOUBLE   ' Setpoint weighting for proportional action
    Gamma           AS DOUBLE   ' Setpoint weighting for derivative action

    ' Dynamic Integrator and Derivative Memory
    IntegratorState AS DOUBLE   ' Accumulated integral action sum
    PrevProcessVar  AS DOUBLE   ' Process variable from previous cycle
    PrevDerivative  AS DOUBLE   ' Filtered derivative term from previous cycle
    PrevError       AS DOUBLE   ' Error term from previous cycle (SP - PV)

    ' Actuator Span Limits and Anti-Windup
    OutMin          AS DOUBLE   ' Output lower saturation limit (0.0%)
    OutMax          AS DOUBLE   ' Output upper saturation limit (100.0%)
    AntiWindupMode  AS INTEGER  ' 0: Clamp, 1: Back-calculation, 2: Freeze
    TrackingTimeConst AS DOUBLE ' Anti-windup reset tracking constant Tt

    ' Execution Timing
    SampleTimeSec   AS DOUBLE   ' Loop execution period Delta T (seconds)
    LastExecTimeMs  AS DOUBLE   ' System clock at previous iteration
END TYPE

' AlarmDefinition: Configuration and dynamic lifecycle for an alarm point
TYPE AlarmDefinition
    AlarmId         AS INTEGER  ' Unique alarm identity index
    TagId           AS INTEGER  ' Associated process tag identifier
    AlarmType       AS INTEGER  ' Low-Low, Low, High, High-High, Rate-of-Change
    Severity        AS INTEGER  ' Diagnostic, Low, Medium, High, Emergency
    State           AS INTEGER  ' Normal, Unack, Acked, RTN_Unack, Shelved

    TripLimit       AS DOUBLE   ' Numeric engineering unit trigger threshold
    Hysteresis      AS DOUBLE   ' Deadband required to clear trip condition
    DeadbandDelayMs AS DOUBLE   ' Anti-chatter on-delay verification period

    TripTimestampMs AS DOUBLE   ' Clock time when limit was breached
    AckTimestampMs  AS DOUBLE   ' Clock time when operator acknowledged
    RtnTimestampMs  AS DOUBLE   ' Clock time when process returned to normal

    ShelveTimeoutMs AS DOUBLE   ' Remaining duration for operator shelving
    IsShelved       AS INTEGER  ' 1 if actively shelved, 0 otherwise
    IsLatched       AS INTEGER  ' 1 if requires manual reset even after RTN
    FirstOutGroup   AS INTEGER  ' Group index for trip cascade attribution
    IsFirstOutRoot  AS INTEGER  ' 1 if this alarm caused the trip cascade
END TYPE

' SdtCompressorRecord: Swinging Door Trending compression variables
TYPE SdtCompressorRecord
    SeriesId        AS INTEGER  ' Historical series identity
    TagId           AS INTEGER  ' Monitored process tag identity
    CompTolerance   AS DOUBLE   ' Epsilon compression deviation in EU
    MinIntervalMs   AS DOUBLE   ' Boxcar minimum time delta between points
    MaxIntervalMs   AS DOUBLE   ' Maximum holding period before forced save

    LastArchivedTime AS DOUBLE  ' Timestamp of the current origin point (t0)
    LastArchivedVal  AS DOUBLE  ' Value of the current origin point (y0)
    PrevSampleTime   AS DOUBLE  ' Timestamp of the preceding point (t_prev)
    PrevSampleVal    AS DOUBLE  ' Value of the preceding point (y_prev)
    HasFirstPoint    AS INTEGER ' 1 if origin point has been established

    SlopeUpper       AS DOUBLE  ' Current running upper door slope constraint
    SlopeLower       AS DOUBLE  ' Current running lower door slope constraint

    TotalRawPoints   AS DOUBLE  ' Ingested sample counter
    TotalSavedPoints AS DOUBLE  ' Emitted archive record counter
END TYPE

' ModbusTransactionRecord: Protocol request/response framing buffer
TYPE ModbusTransactionRecord
    TransactionId   AS INTEGER  ' 16-bit MBAP Transaction Identifier
    ProtocolId      AS INTEGER  ' Protocol ID: 0 for standard Modbus TCP
    UnitId          AS INTEGER  ' Remote slave/station address (1 to 247)
    FunctionCode    AS INTEGER  ' Modbus function code (01, 03, 06, 16, etc.)
    StartAddress    AS INTEGER  ' Zero-based target memory offset
    PointCount      AS INTEGER  ' Number of coils or registers requested
    ByteCount       AS INTEGER  ' Data payload size in bytes
    ExceptionCode   AS INTEGER  ' 0 if successful, non-zero error response
    IsCompleted     AS INTEGER  ' 1 if transaction completed, 0 if pending
END TYPE

' BatchPhaseRecord: ISA-88 Unit procedure phase configuration
TYPE BatchPhaseRecord
    PhaseId         AS INTEGER  ' Phase sequence identifier
    PhaseName       AS STRING   ' Phase name (e.g., DOSING_SOLVENT)
    BatchId         AS STRING   ' Active batch production lot number
    CurrentState    AS INTEGER  ' Idle, Running, Holding, Completed, Aborted
    ElapsedSeconds  AS DOUBLE   ' Total run time accumulated in phase
    TargetDuration  AS DOUBLE   ' Nominal duration or timeout setpoint
    CurrentStep     AS INTEGER  ' Internal sub-step sequencing pointer
    TotalSteps      AS INTEGER  ' Number of sequential sub-steps in phase
    IsInterlocked   AS INTEGER  ' 1 if safety interlock halts execution
END TYPE

' Matrix3x3: 3x3 Double precision matrix for state estimation and dynamics
TYPE Matrix3x3
    M00 AS DOUBLE : M01 AS DOUBLE : M02 AS DOUBLE
    M10 AS DOUBLE : M11 AS DOUBLE : M12 AS DOUBLE
    M20 AS DOUBLE : M21 AS DOUBLE : M22 AS DOUBLE
END TYPE

' Vector3: 3-dimensional vector for kinematic, mass balance, or state vectors
TYPE Vector3
    X AS DOUBLE
    Y AS DOUBLE
    Z AS DOUBLE
END TYPE

' ------------------------------------------------------------------------------
' SECTION 3: UTILITY INITIALIZATION PROCEDURES
' ------------------------------------------------------------------------------

' InitializeTagDefinition: Sets safe baseline defaults for a process tag
SUB InitializeTagDefinition(tag AS TagDefinition, id AS INTEGER, name AS STRING, tType AS INTEGER, minVal AS DOUBLE, maxVal AS DOUBLE)
    tag.TagId = id
    tag.TagName = name
    tag.TagType = tType
    tag.Quality = QUALITY_GOOD
    tag.EuValue = minVal
    tag.RawValue = 0.0
    tag.EuMin = minVal
    tag.EuMax = maxVal
    tag.RawMin = 0.0
    tag.RawMax = 65535.0
    tag.DeadbandAbs = (maxVal - minVal) * 0.001
    tag.DeadbandPct = 0.1
    tag.LastEmittedVal = minVal
    tag.TimestampMs = 0.0
    tag.IsSimulated = 0
    tag.IsClamped = 0
END SUB

' InitializePidState: Configures standard ISA tuning defaults for a control loop
SUB InitializePidState(pid AS PidControllerState, id AS INTEGER, kp AS DOUBLE, ti AS DOUBLE, td AS DOUBLE, dt AS DOUBLE)
    pid.LoopId = id
    pid.Mode = CTRL_MODE_MANUAL
    pid.Setpoint = 0.0
    pid.ProcessVariable = 0.0
    pid.ControlOutput = 0.0
    pid.ManualOutput = 0.0

    pid.Kp = kp
    pid.Ti = ti
    pid.Td = td
    pid.Alpha = 0.1
    pid.Beta = 1.0
    pid.Gamma = 0.0

    pid.IntegratorState = 0.0
    pid.PrevProcessVar = 0.0
    pid.PrevDerivative = 0.0
    pid.PrevError = 0.0

    pid.OutMin = 0.0
    pid.OutMax = 100.0
    pid.AntiWindupMode = 1  ' Back-calculation
    pid.TrackingTimeConst = SQR(ti * td)
    IF pid.TrackingTimeConst < dt THEN
        pid.TrackingTimeConst = dt
    END IF

    pid.SampleTimeSec = dt
    pid.LastExecTimeMs = 0.0
END SUB

' InitializeAlarmDefinition: Sets default operational bounds for an alarm
SUB InitializeAlarmDefinition(alm AS AlarmDefinition, id AS INTEGER, tagId AS INTEGER, aType AS INTEGER, sev AS INTEGER, trip AS DOUBLE, hyst AS DOUBLE)
    alm.AlarmId = id
    alm.TagId = tagId
    alm.AlarmType = aType
    alm.Severity = sev
    alm.State = ALARM_STATE_NORMAL
    alm.TripLimit = trip
    alm.Hysteresis = hyst
    alm.DeadbandDelayMs = 1000.0  ' 1.0 second verification delay
    alm.TripTimestampMs = 0.0
    alm.AckTimestampMs = 0.0
    alm.RtnTimestampMs = 0.0
    alm.ShelveTimeoutMs = 0.0
    alm.IsShelved = 0
    alm.IsLatched = 0
    alm.FirstOutGroup = 0
    alm.IsFirstOutRoot = 0
END SUB
