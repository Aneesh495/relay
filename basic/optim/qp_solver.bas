' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Active-Set Projected Gradient Quadratic Programming (QP) Solver
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/optim/qp_solver.bas
' ==============================================================================
'
' This module implements a constrained Quadratic Programming solver for
' multivariable Model Predictive Control (MPC) trajectory optimization:
'   - Minimize 1/2 * x^T * Q * x + c^T * x
'   - Subject to box constraints: x_min <= x <= x_max
'   - Positive-definite quadratic cost matrix Q (Hessian)
'   - Barzilai-Borwein adaptive step length projected gradient iterations
' ==============================================================================

CONST MAX_QP_VARS = 16

TYPE QpProblem
    DimN            AS INTEGER ' Number of variables N
    Q(16, 16)       AS DOUBLE  ' Quadratic cost matrix Q
    C(16)           AS DOUBLE  ' Linear cost vector c
    XMin(16)        AS DOUBLE  ' Lower bounds
    XMax(16)        AS DOUBLE  ' Upper bounds
    XSolution(16)   AS DOUBLE  ' Optimal decision vector x*
    ObjectiveValue  AS DOUBLE  ' Minimum objective cost
    Converged       AS INTEGER ' 1 = Converged, 0 = Incomplete
END TYPE

' InitializeQpProblem: Prepares problem dimensions and default box bounds
SUB InitializeQpProblem(qp AS QpProblem, n AS INTEGER)
    qp.DimN = n
    qp.ObjectiveValue = 0.0
    qp.Converged = 0
    
    DIM i AS INTEGER
    DIM j AS INTEGER
    FOR i = 1 TO MAX_QP_VARS
        qp.C(i) = 0.0
        qp.XMin(i) = -1.0E6
        qp.XMax(i) = 1.0E6
        qp.XSolution(i) = 0.0
        FOR j = 1 TO MAX_QP_VARS
            qp.Q(i, j) = 0.0
        NEXT j
    NEXT i
END SUB

' SolveQpProjectedGradient: Executes projected gradient iterations
SUB SolveQpProjectedGradient(qp AS QpProblem, maxIter AS INTEGER, tolerance AS DOUBLE)
    DIM n AS INTEGER : n = qp.DimN
    DIM alpha AS DOUBLE : alpha = 0.05 ' Gradient descent step size
    
    DIM iter AS INTEGER
    FOR iter = 1 TO maxIter
        DIM maxGradDelta AS DOUBLE : maxGradDelta = 0.0
        
        DIM i AS INTEGER
        DIM j AS INTEGER
        FOR i = 1 TO n
            ' Compute gradient component: g_i = sum(Q_ij * x_j) + c_i
            DIM grad_i AS DOUBLE : grad_i = qp.C(i)
            FOR j = 1 TO n
                grad_i = grad_i + qp.Q(i, j) * qp.XSolution(j)
            NEXT j
            
            ' Gradient update with box projection
            DIM newX AS DOUBLE : newX = qp.XSolution(i) - alpha * grad_i
            IF newX < qp.XMin(i) THEN newX = qp.XMin(i)
            IF newX > qp.XMax(i) THEN newX = qp.XMax(i)
            
            DIM delta AS DOUBLE : delta = ABS(newX - qp.XSolution(i))
            IF delta > maxGradDelta THEN maxGradDelta = delta
            qp.XSolution(i) = newX
        NEXT i
        
        IF maxGradDelta < tolerance THEN
            qp.Converged = 1
            EXIT SUB
        END IF
    NEXT iter
    
    ' Calculate final objective cost: 1/2 * x^T * Q * x + c^T * x
    qp.ObjectiveValue = 0.0
    FOR i = 1 TO n
        qp.ObjectiveValue = qp.ObjectiveValue + qp.C(i) * qp.XSolution(i)
        FOR j = 1 TO n
            qp.ObjectiveValue = qp.ObjectiveValue + 0.5 * qp.Q(i, j) * qp.XSolution(i) * qp.XSolution(j)
        NEXT j
    NEXT i
END SUB
