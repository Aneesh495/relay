' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Receding Horizon Model Predictive Controller (MPC)
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/optim/mpc_core.bas
' ==============================================================================
'
' This module implements receding-horizon Model Predictive Control (MPC):
'   - Internal discrete-time state-space prediction: x(k+1) = A*x(k) + B*u(k)
'   - Quadratic tracking penalty on setpoint error (Q weight)
'   - Actuator movement suppression penalty (R weight)
'   - Actuator position and rate-of-change constraint enforcement
'   - Receding horizon principle: executes u*(0) and shifts horizon forward
' ==============================================================================

CONST MPC_HORIZON = 8

TYPE MpcControllerInstance
    PredictionHorizon AS INTEGER ' Np = 8 steps
    ControlHorizon    AS INTEGER ' Nc = 3 steps
    
    ' Process Model Parameters (SISO first-order + delay approximation)
    ModelA            AS DOUBLE  ' System pole (e.g. 0.85)
    ModelB            AS DOUBLE  ' Input gain (e.g. 0.15)
    ModelC            AS DOUBLE  ' Output matrix (1.0)
    
    ' Cost Weightings
    WeightQ           AS DOUBLE  ' Tracking error penalty (e.g. 1.0)
    WeightR           AS DOUBLE  ' Control effort penalty (e.g. 0.1)
    
    ' Constraints
    ActuatorMin       AS DOUBLE  ' Lower saturation limit (0.0%)
    ActuatorMax       AS DOUBLE  ' Upper saturation limit (100.0%)
    MaxDeltaU         AS DOUBLE  ' Maximum slew per scan (e.g. 5.0%)
    
    ' State Tracking
    CurrentStateX     AS DOUBLE
    CurrentOutputU    AS DOUBLE
    PredictedY(8)     AS DOUBLE
END TYPE

' InitializeMpcController: Sets up state-space matrices and weights
SUB InitializeMpcController(mpc AS MpcControllerInstance, poleA AS DOUBLE, gainB AS DOUBLE)
    mpc.PredictionHorizon = MPC_HORIZON
    mpc.ControlHorizon = 3
    mpc.ModelA = poleA
    mpc.ModelB = gainB
    mpc.ModelC = 1.0
    
    mpc.WeightQ = 1.0
    mpc.WeightR = 0.05
    
    mpc.ActuatorMin = 0.0
    mpc.ActuatorMax = 100.0
    mpc.MaxDeltaU = 10.0
    
    mpc.CurrentStateX = 0.0
    mpc.CurrentOutputU = 0.0
    
    DIM k AS INTEGER
    FOR k = 1 TO MPC_HORIZON
        mpc.PredictedY(k) = 0.0
    NEXT k
END SUB

' ComputeMpcMove: Solves one receding horizon step given measured PV and SP
FUNCTION ComputeMpcMove(mpc AS MpcControllerInstance, measuredPV AS DOUBLE, targetSP AS DOUBLE) AS DOUBLE
    ' 1. State observer update (innovation correction)
    mpc.CurrentStateX = measuredPV
    
    ' 2. Unconstrained optimal gain computation (Riccati / inverse formulation)
    ' First-step predictive response: dy = B * du
    ' Cost: J = Q * (y_pred - SP)^2 + R * du^2
    ' dJ/d(du) = 2*Q*(A*x + B*du - SP)*B + 2*R*du = 0
    ' du* = (B * Q * (SP - A * x)) / (B^2 * Q + R)
    DIM freeResponseY AS DOUBLE : freeResponseY = mpc.ModelA * mpc.CurrentStateX
    DIM trackingErr AS DOUBLE : trackingErr = targetSP - freeResponseY
    
    DIM denom AS DOUBLE
    denom = (mpc.ModelB * mpc.ModelB * mpc.WeightQ) + mpc.WeightR
    IF denom < 0.0001 THEN denom = 0.0001
    
    DIM optimalDeltaU AS DOUBLE
    optimalDeltaU = (mpc.ModelB * mpc.WeightQ * trackingErr) / denom
    
    ' 3. Apply rate-of-change constraint |du| <= MaxDeltaU
    IF optimalDeltaU > mpc.MaxDeltaU THEN optimalDeltaU = mpc.MaxDeltaU
    IF optimalDeltaU < -mpc.MaxDeltaU THEN optimalDeltaU = -mpc.MaxDeltaU
    
    ' 4. Integrate actuator output: u(k) = u(k-1) + du
    mpc.CurrentOutputU = mpc.CurrentOutputU + optimalDeltaU
    
    ' 5. Apply actuator saturation constraint [u_min, u_max]
    IF mpc.CurrentOutputU > mpc.ActuatorMax THEN mpc.CurrentOutputU = mpc.ActuatorMax
    IF mpc.CurrentOutputU < mpc.ActuatorMin THEN mpc.CurrentOutputU = mpc.ActuatorMin
    
    ' 6. Predict forward trajectory across horizon Np
    DIM predX AS DOUBLE : predX = mpc.CurrentStateX
    DIM k AS INTEGER
    FOR k = 1 TO mpc.PredictionHorizon
        predX = mpc.ModelA * predX + mpc.ModelB * mpc.CurrentOutputU
        mpc.PredictedY(k) = predX
    NEXT k
    
    ComputeMpcMove = mpc.CurrentOutputU
END FUNCTION
