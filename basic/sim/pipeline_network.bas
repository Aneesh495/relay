' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Looped Pipeline Hydraulic Network & Hardy-Cross Flow Balancer
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/pipeline_network.bas
' ==============================================================================
'
' This module implements the Hardy-Cross iterative loop head loss balance
' algorithm for municipal and petrochemical fluid distribution grids:
'   - Darcy-Weisbach pipe friction head loss: h_f = r * Q * |Q|
'   - Conservation of mass (Kirchhoff Current Law) at junction nodes
'   - Conservation of mechanical energy (Kirchhoff Voltage Law) around loops
'   - Iterative flow rate corrections: Delta Q = - sum(h_f) / (2 * sum(r * |Q|))
' ==============================================================================

CONST MAX_PIPES = 8
CONST MAX_NODES = 6

TYPE NetworkPipe
    PipeId          AS INTEGER
    FromNode        AS INTEGER
    ToNode          AS INTEGER
    LengthM         AS DOUBLE  ' Pipe length in meters
    DiameterMm      AS DOUBLE  ' Inside diameter
    ResistanceCoeffR AS DOUBLE ' Hydraulic resistance r = (f * L) / (2 * g * D * A^2)
    FlowRateM3H     AS DOUBLE  ' Signed volumetric flow rate Q
    HeadLossM       AS DOUBLE  ' Friction head loss h_f = r * Q * |Q|
END TYPE

TYPE NetworkNode
    NodeId          AS INTEGER
    ElevationM      AS DOUBLE  ' Ground elevation z
    PressureHeadM   AS DOUBLE  ' Piezometric head H = z + P / gamma
    DemandFlowM3H   AS DOUBLE  ' External consumer withdrawal flow
END TYPE

TYPE HydraulicNetworkState
    Pipes(8)        AS NetworkPipe
    Nodes(6)        AS NetworkNode
    NumPipes        AS INTEGER
    NumNodes        AS INTEGER
    SupplyPressureBar AS DOUBLE' Inflow boundary pressure at reservoir node 1
    LoopResidualHeadM AS DOUBLE' Maximum closure imbalance around loops
END TYPE

' InitializePipelineNetwork: Sets up standard 2-loop 7-pipe industrial distribution grid
SUB InitializePipelineNetwork(net AS HydraulicNetworkState)
    net.NumPipes = 7
    net.NumNodes = 6
    net.SupplyPressureBar = 6.0
    net.LoopResidualHeadM = 0.0
    
    ' Nodes: Node 1 is supply reservoir; 2..6 are demand junctions
    DIM n AS INTEGER
    FOR n = 1 TO 6
        net.Nodes(n).NodeId = n
        net.Nodes(n).ElevationM = 10.0 + (n * 2.5)
        net.Nodes(n).PressureHeadM = 60.0
        IF n = 1 THEN
            net.Nodes(n).DemandFlowM3H = -350.0 ' Total inflow supply
        ELSE
            net.Nodes(n).DemandFlowM3H = 70.0   ' 70 m^3/h consumer draw
        END IF
    NEXT n
    
    ' Configure 7 pipes forming 2 closed loops
    ' Loop 1: Pipes 1, 2, 3, 4
    ' Loop 2: Pipes 3, 5, 6, 7 (Pipe 3 is shared partition)
    DIM p AS INTEGER
    FOR p = 1 TO 7
        net.Pipes(p).PipeId = p
        net.Pipes(p).LengthM = 400.0
        net.Pipes(p).DiameterMm = 200.0
        net.Pipes(p).ResistanceCoeffR = 0.000045 ' Resistance coefficient
        net.Pipes(p).FlowRateM3H = 80.0
        net.Pipes(p).HeadLossM = 0.0
    NEXT p
END SUB

' StepHardyCrossBalance: Executes one relaxation iteration around hydraulic loops
SUB StepHardyCrossBalance(net AS HydraulicNetworkState)
    ' 1. Calculate head loss for every pipe: h_f = r * Q * |Q|
    DIM p AS INTEGER
    FOR p = 1 TO net.NumPipes
        DIM qVal AS DOUBLE : qVal = net.Pipes(p).FlowRateM3H
        DIM rVal AS DOUBLE : rVal = net.Pipes(p).ResistanceCoeffR
        net.Pipes(p).HeadLossM = rVal * qVal * ABS(qVal)
    NEXT p
    
    ' 2. Loop 1 Evaluation: Pipes 1, 2, 3, 4
    ' Sum head losses around clockwise loop: h_loop = h1 + h2 + h3 - h4
    DIM sumH1 AS DOUBLE
    sumH1 = net.Pipes(1).HeadLossM + net.Pipes(2).HeadLossM + net.Pipes(3).HeadLossM - net.Pipes(4).HeadLossM
    
    DIM sumDeriv1 AS DOUBLE
    sumDeriv1 = 2.0 * (net.Pipes(1).ResistanceCoeffR * ABS(net.Pipes(1).FlowRateM3H) + _
                       net.Pipes(2).ResistanceCoeffR * ABS(net.Pipes(2).FlowRateM3H) + _
                       net.Pipes(3).ResistanceCoeffR * ABS(net.Pipes(3).FlowRateM3H) + _
                       net.Pipes(4).ResistanceCoeffR * ABS(net.Pipes(4).FlowRateM3H))
    
    IF sumDeriv1 > 0.000001 THEN
        DIM deltaQ1 AS DOUBLE : deltaQ1 = -sumH1 / sumDeriv1
        ' Apply loop 1 flow corrections
        net.Pipes(1).FlowRateM3H = net.Pipes(1).FlowRateM3H + deltaQ1
        net.Pipes(2).FlowRateM3H = net.Pipes(2).FlowRateM3H + deltaQ1
        net.Pipes(3).FlowRateM3H = net.Pipes(3).FlowRateM3H + deltaQ1
        net.Pipes(4).FlowRateM3H = net.Pipes(4).FlowRateM3H - deltaQ1
    END IF
    
    net.LoopResidualHeadM = ABS(sumH1)
END SUB
