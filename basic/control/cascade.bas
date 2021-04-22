' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Master-Slave Cascade Control Architecture
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/control/cascade.bas
' ==============================================================================
'
' This module implements primary/secondary cascade control loops. The master
' loop regulates the primary process variable (e.g., column temperature) by
' manipulating the setpoint of the fast inner slave loop (e.g., heating steam flow).
' ==============================================================================

' CascadeLoopPair: Dual-loop coordination structure
TYPE CascadeLoopPair
    MasterLoop      AS PidControllerState  ' Primary slow outer loop
    SlaveLoop       AS PidControllerState  ' Secondary fast inner loop
    CascadeEngaged  AS INTEGER             ' 1 if slave setpoint driven by master
    SlaveSpMin      AS DOUBLE              ' Allowable slave setpoint lower limit
    SlaveSpMax      AS DOUBLE              ' Allowable slave setpoint upper limit
END TYPE

' InitializeCascadePair: Prepares master-slave loop relationship
SUB InitializeCascadePair(casc AS CascadeLoopPair, masterId AS INTEGER, slaveId AS INTEGER, _
                          slaveSpMin AS DOUBLE, slaveSpMax AS DOUBLE)
    InitializePidState(casc.MasterLoop, masterId, 1.5, 60.0, 5.0, 0.1)
    InitializePidState(casc.SlaveLoop, slaveId, 0.8, 5.0, 0.0, 0.05)
    casc.CascadeEngaged = 0
    casc.SlaveSpMin = slaveSpMin
    casc.SlaveSpMax = slaveSpMax
END SUB

' ExecuteCascadeCycle: Computes synchronized master and slave control steps
SUB ExecuteCascadeCycle(casc AS CascadeLoopPair, masterSp AS DOUBLE, masterPv AS DOUBLE, _
                        slavePv AS DOUBLE, dtSec AS DOUBLE)
    ' 1. Check if Slave is in Manual mode
    IF casc.SlaveLoop.Mode = CTRL_MODE_MANUAL THEN
        ' Cascade cannot be active if slave is in manual!
        casc.CascadeEngaged = 0
        ' Master must track slave setpoint to prevent master integrator windup:
        casc.MasterLoop.Mode = CTRL_MODE_TRACKING
        casc.MasterLoop.ControlOutput = casc.SlaveLoop.Setpoint
        casc.MasterLoop.IntegratorState = casc.SlaveLoop.Setpoint - casc.MasterLoop.Kp * (casc.MasterLoop.Beta * masterSp - masterPv)
        EXIT SUB
    END IF

    ' 2. Execute Master Loop
    IF casc.CascadeEngaged = 1 THEN
        casc.MasterLoop.Mode = CTRL_MODE_AUTO
        ExecutePidCycle(casc.MasterLoop, masterSp, masterPv, 0.0, dtSec)

        ' Master output commands the Slave setpoint
        DIM targetSlaveSp AS DOUBLE
        targetSlaveSp = ClampValue(casc.MasterLoop.ControlOutput, casc.SlaveSpMin, casc.SlaveSpMax)
        casc.SlaveLoop.Setpoint = targetSlaveSp

        ' 3. Execute Slave Loop with updated setpoint
        ExecutePidCycle(casc.SlaveLoop, casc.SlaveLoop.Setpoint, slavePv, 0.0, dtSec)
    ELSE
        ' Standalone slave operation: master in tracking mode
        ExecutePidCycle(casc.SlaveLoop, casc.SlaveLoop.Setpoint, slavePv, casc.SlaveLoop.ManualOutput, dtSec)
        casc.MasterLoop.Mode = CTRL_MODE_TRACKING
        casc.MasterLoop.ControlOutput = casc.SlaveLoop.Setpoint
    END IF
END SUB
