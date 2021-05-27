' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' ANSI/ISA-88 Procedural Batch Control State Machine
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sequence/isa88_batch.bas
' ==============================================================================
'
' This module implements the international batch control standard ANSI/ISA-88
' (IEC 61512-1). It governs recipe phase transitions, manual holds, pause/resume
' operations, and emergency abort sequences.
' ==============================================================================

' ISA-88 Operator Commands
CONST BATCH_CMD_START    = 1
CONST BATCH_CMD_STOP     = 2
CONST BATCH_CMD_HOLD     = 3
CONST BATCH_CMD_UNHOLD   = 4
CONST BATCH_CMD_PAUSE    = 5
CONST BATCH_CMD_RESUME   = 6
CONST BATCH_CMD_ABORT    = 7
CONST BATCH_CMD_RESET    = 8

' ProcessIsa88Command: Evaluates command against current state and transitions state
FUNCTION ProcessIsa88Command(currentState AS INTEGER, command AS INTEGER) AS INTEGER
    ' Emergency Abort is always permitted from any active state
    IF command = BATCH_CMD_ABORT THEN
        RETURN BATCH_STATE_ABORTING
    END IF

    IF currentState = BATCH_STATE_IDLE THEN
        IF command = BATCH_CMD_START THEN
            RETURN BATCH_STATE_RUNNING
        END IF

    ELSEIF currentState = BATCH_STATE_RUNNING THEN
        IF command = BATCH_CMD_HOLD THEN
            RETURN BATCH_STATE_HOLDING
        ELSEIF command = BATCH_CMD_PAUSE THEN
            RETURN BATCH_STATE_PAUSING
        ELSEIF command = BATCH_CMD_STOP THEN
            RETURN BATCH_STATE_STOPPING
        END IF

    ELSEIF currentState = BATCH_STATE_PAUSING THEN
        ' System completes active transient sub-step, then transitions to PAUSED
        RETURN BATCH_STATE_PAUSED

    ELSEIF currentState = BATCH_STATE_PAUSED THEN
        IF command = BATCH_CMD_RESUME THEN
            RETURN BATCH_STATE_RUNNING
        ELSEIF command = BATCH_CMD_HOLD THEN
            RETURN BATCH_STATE_HOLDING
        END IF

    ELSEIF currentState = BATCH_STATE_HOLDING THEN
        ' System brings reactor to safe holding state, then transitions to HELD
        RETURN BATCH_STATE_HELD

    ELSEIF currentState = BATCH_STATE_HELD THEN
        IF command = BATCH_CMD_UNHOLD THEN
            RETURN BATCH_STATE_RESTARTING
        END IF

    ELSEIF currentState = BATCH_STATE_RESTARTING THEN
        ' Re-verifies permissives, then resumes RUNNING
        RETURN BATCH_STATE_RUNNING

    ELSEIF currentState = BATCH_STATE_COMPLETING THEN
        RETURN BATCH_STATE_COMPLETED

    ELSEIF currentState = BATCH_STATE_COMPLETED THEN
        IF command = BATCH_CMD_RESET THEN
            RETURN BATCH_STATE_IDLE
        END IF

    ELSEIF currentState = BATCH_STATE_ABORTING THEN
        RETURN BATCH_STATE_ABORTED

    ELSEIF currentState = BATCH_STATE_ABORTED THEN
        IF command = BATCH_CMD_RESET THEN
            RETURN BATCH_STATE_IDLE
        END IF

    ELSEIF currentState = BATCH_STATE_STOPPING THEN
        RETURN BATCH_STATE_STOPPED

    ELSEIF currentState = BATCH_STATE_STOPPED THEN
        IF command = BATCH_CMD_RESET THEN
            RETURN BATCH_STATE_IDLE
        END IF
    END IF

    ' Illegal command ignored, retain current state
    RETURN currentState
END FUNCTION
