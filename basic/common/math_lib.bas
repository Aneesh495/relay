' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' High-Precision Applied Mathematics & Numerical Integration Library
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/common/math_lib.bas
' ==============================================================================
'
' This module implements high-precision numerical algorithms, matrix mathematics,
' statistical estimators, and ODE differential equation solvers required for
' advanced process control (APC), digital twin plant modeling, and signal filtering.
' ==============================================================================

CONST MATH_PI       = 3.141592653589793
CONST MATH_E        = 2.718281828459045
CONST MATH_EPSILON  = 1.0E-12

' ------------------------------------------------------------------------------
' SECTION 1: SCALAR AND TRANSCENDENTAL FUNCTIONS
' ------------------------------------------------------------------------------

' SafeDivide: Performs division with protection against zero-denominator faults
FUNCTION SafeDivide(numerator AS DOUBLE, denominator AS DOUBLE, fallback AS DOUBLE) AS DOUBLE
    IF ABS(denominator) < MATH_EPSILON THEN
        RETURN fallback
    END IF
    RETURN numerator / denominator
END FUNCTION

' ClampValue: Restricts a double-precision scalar to specified lower and upper bounds
FUNCTION ClampValue(val AS DOUBLE, minLimit AS DOUBLE, maxLimit AS DOUBLE) AS DOUBLE
    IF val < minLimit THEN
        RETURN minLimit
    END IF
    IF val > maxLimit THEN
        RETURN maxLimit
    END IF
    RETURN val
END FUNCTION

' LerpValue: Linear interpolation between two points given normalized alpha in [0, 1]
FUNCTION LerpValue(v0 AS DOUBLE, v1 AS DOUBLE, alpha AS DOUBLE) AS DOUBLE
    RETURN v0 + alpha * (v1 - v0)
END FUNCTION

' SignValue: Returns +1 for positive numbers, -1 for negative, and 0 for zero
FUNCTION SignValue(val AS DOUBLE) AS DOUBLE
    IF val > MATH_EPSILON THEN
        RETURN 1.0
    END IF
    IF val < -MATH_EPSILON THEN
        RETURN -1.0
    END IF
    RETURN 0.0
END FUNCTION

' HornerPolynomial: Evaluates an n-th degree polynomial using Horner's method
' coefficients array: a0, a1, a2, ..., an where P(x) = a0 + a1*x + a2*x^2 + ...
FUNCTION HornerPolynomial(x AS DOUBLE, coeffs(10) AS DOUBLE, degree AS INTEGER) AS DOUBLE
    DIM result AS DOUBLE
    DIM i AS INTEGER
    result = coeffs(degree)
    FOR i = degree - 1 TO 0 STEP -1
        result = result * x + coeffs(i)
    NEXT i
    RETURN result
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 2: VECTOR AND MATRIX LINEAR ALGEBRA
' ------------------------------------------------------------------------------

' Vector3Add: Computes vector sum R = A + B
SUB Vector3Add(a AS Vector3, b AS Vector3, result AS Vector3)
    result.X = a.X + b.X
    result.Y = a.Y + b.Y
    result.Z = a.Z + b.Z
END SUB

' Vector3Subtract: Computes vector difference R = A - B
SUB Vector3Subtract(a AS Vector3, b AS Vector3, result AS Vector3)
    result.X = a.X - b.X
    result.Y = a.Y - b.Y
    result.Z = a.Z - b.Z
END SUB

' Vector3Scale: Scales vector A by scalar factor k
SUB Vector3Scale(a AS Vector3, k AS DOUBLE, result AS Vector3)
    result.X = a.X * k
    result.Y = a.Y * k
    result.Z = a.Z * k
END SUB

' Vector3Dot: Returns the scalar dot product of vectors A and B
FUNCTION Vector3Dot(a AS Vector3, b AS Vector3) AS DOUBLE
    RETURN a.X * b.X + a.Y * b.Y + a.Z * b.Z
END FUNCTION

' Vector3Cross: Computes the cross product vector R = A x B
SUB Vector3Cross(a AS Vector3, b AS Vector3, result AS Vector3)
    result.X = a.Y * b.Z - a.Z * b.Y
    result.Y = a.Z * b.X - a.X * b.Z
    result.Z = a.X * b.Y - a.Y * b.X
END SUB

' Vector3Norm: Computes the Euclidean L2 norm of vector A
FUNCTION Vector3Norm(a AS Vector3) AS DOUBLE
    RETURN SQR(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
END FUNCTION

' Matrix3x3Identity: Initializes matrix M as the 3x3 identity matrix
SUB Matrix3x3Identity(m AS Matrix3x3)
    m.M00 = 1.0 : m.M01 = 0.0 : m.M02 = 0.0
    m.M10 = 0.0 : m.M11 = 1.0 : m.M12 = 0.0
    m.M20 = 0.0 : m.M21 = 0.0 : m.M22 = 1.0
END SUB

' Matrix3x3Multiply: Computes matrix product R = A * B
SUB Matrix3x3Multiply(a AS Matrix3x3, b AS Matrix3x3, result AS Matrix3x3)
    result.M00 = a.M00 * b.M00 + a.M01 * b.M10 + a.M02 * b.M20
    result.M01 = a.M00 * b.M01 + a.M01 * b.M11 + a.M02 * b.M21
    result.M02 = a.M00 * b.M02 + a.M01 * b.M12 + a.M02 * b.M22

    result.M10 = a.M10 * b.M00 + a.M11 * b.M10 + a.M12 * b.M20
    result.M11 = a.M10 * b.M01 + a.M11 * b.M11 + a.M12 * b.M21
    result.M12 = a.M10 * b.M02 + a.M11 * b.M12 + a.M12 * b.M22

    result.M20 = a.M20 * b.M00 + a.M21 * b.M10 + a.M22 * b.M20
    result.M21 = a.M20 * b.M01 + a.M21 * b.M11 + a.M22 * b.M21
    result.M22 = a.M20 * b.M02 + a.M21 * b.M12 + a.M22 * b.M22
END SUB

' Matrix3x3Determinant: Calculates the scalar determinant of a 3x3 matrix
FUNCTION Matrix3x3Determinant(m AS Matrix3x3) AS DOUBLE
    DIM det AS DOUBLE
    det = m.M00 * (m.M11 * m.M22 - m.M12 * m.M21) - _
          m.M01 * (m.M10 * m.M22 - m.M12 * m.M20) + _
          m.M02 * (m.M10 * m.M21 - m.M11 * m.M20)
    RETURN det
END FUNCTION

' Matrix3x3Inverse: Inverts a 3x3 matrix via adjugate formulation
FUNCTION Matrix3x3Inverse(m AS Matrix3x3, inv AS Matrix3x3) AS INTEGER
    DIM det AS DOUBLE
    det = Matrix3x3Determinant(m)
    IF ABS(det) < MATH_EPSILON THEN
        ' Singular matrix, inversion impossible
        RETURN 0
    END IF

    DIM invDet AS DOUBLE
    invDet = 1.0 / det

    inv.M00 = (m.M11 * m.M22 - m.M12 * m.M21) * invDet
    inv.M01 = (m.M02 * m.M21 - m.M01 * m.M22) * invDet
    inv.M02 = (m.M01 * m.M12 - m.M02 * m.M11) * invDet

    inv.M10 = (m.M12 * m.M20 - m.M10 * m.M22) * invDet
    inv.M11 = (m.M00 * m.M22 - m.M02 * m.M20) * invDet
    inv.M12 = (m.M02 * m.M10 - m.M00 * m.M12) * invDet

    inv.M20 = (m.M10 * m.M21 - m.M11 * m.M20) * invDet
    inv.M21 = (m.M01 * m.M20 - m.M00 * m.M21) * invDet
    inv.M22 = (m.M00 * m.M11 - m.M01 * m.M10) * invDet

    RETURN 1
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 3: NUMERICAL ODE INTEGRATION (RUNGE-KUTTA 4TH ORDER)
' ------------------------------------------------------------------------------

' RK4StepScalar: Executes a single 4th-order Runge-Kutta numerical step for
' the scalar differential equation dy/dt = f(t, y, u).
' k1 = f(t, y)
' k2 = f(t + dt/2, y + dt/2 * k1)
' k3 = f(t + dt/2, y + dt/2 * k2)
' k4 = f(t + dt, y + dt * k3)
' y_{n+1} = y_n + (dt / 6) * (k1 + 2*k2 + 2*k3 + k4)
FUNCTION RK4StepScalar(y AS DOUBLE, u AS DOUBLE, dt AS DOUBLE, tau AS DOUBLE, gain AS DOUBLE) AS DOUBLE
    ' Models standard first-order lag transfer function: tau * dy/dt + y = gain * u
    ' dy/dt = (gain * u - y) / tau
    DIM k1 AS DOUBLE
    DIM k2 AS DOUBLE
    DIM k3 AS DOUBLE
    DIM k4 AS DOUBLE
    DIM dtHalf AS DOUBLE
    dtHalf = dt * 0.5

    k1 = SafeDivide(gain * u - y, tau, 0.0)
    k2 = SafeDivide(gain * u - (y + dtHalf * k1), tau, 0.0)
    k3 = SafeDivide(gain * u - (y + dtHalf * k2), tau, 0.0)
    k4 = SafeDivide(gain * u - (y + dt * k3), tau, 0.0)

    RETURN y + (dt / 6.0) * (k1 + 2.0 * k2 + 2.0 * k3 + k4)
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 4: STATISTICAL ESTIMATORS AND REGRESSION ANALYSIS
' ------------------------------------------------------------------------------

' ComputeMean: Returns arithmetic mean of an array slice
FUNCTION ComputeMean(data(1000) AS DOUBLE, count AS INTEGER) AS DOUBLE
    IF count <= 0 THEN RETURN 0.0
    DIM sumVal AS DOUBLE
    DIM i AS INTEGER
    sumVal = 0.0
    FOR i = 0 TO count - 1
        sumVal = sumVal + data(i)
    NEXT i
    RETURN sumVal / count
END FUNCTION

' ComputeVariance: Calculates the unbiased sample variance
FUNCTION ComputeVariance(data(1000) AS DOUBLE, count AS INTEGER, meanVal AS DOUBLE) AS DOUBLE
    IF count <= 1 THEN RETURN 0.0
    DIM sumSquares AS DOUBLE
    DIM diff AS DOUBLE
    DIM i AS INTEGER
    sumSquares = 0.0
    FOR i = 0 TO count - 1
        diff = data(i) - meanVal
        sumSquares = sumSquares + diff * diff
    NEXT i
    RETURN sumSquares / (count - 1)
END FUNCTION

' ComputeStdDev: Calculates the sample standard deviation
FUNCTION ComputeStdDev(data(1000) AS DOUBLE, count AS INTEGER) AS DOUBLE
    DIM meanVal AS DOUBLE
    DIM varVal AS DOUBLE
    meanVal = ComputeMean(data, count)
    varVal = ComputeVariance(data, count, meanVal)
    IF varVal <= 0.0 THEN RETURN 0.0
    RETURN SQR(varVal)
END FUNCTION

' LinearRegression: Computes least-squares linear trend y = slope * x + intercept
' Also calculates Pearson's correlation coefficient R
SUB LinearRegression(x(1000) AS DOUBLE, y(1000) AS DOUBLE, count AS INTEGER, slope AS DOUBLE, intercept AS DOUBLE, rCoeff AS DOUBLE)
    IF count <= 1 THEN
        slope = 0.0 : intercept = 0.0 : rCoeff = 0.0
        EXIT SUB
    END IF

    DIM sumX AS DOUBLE : DIM sumY AS DOUBLE
    DIM sumXY AS DOUBLE : DIM sumX2 AS DOUBLE : DIM sumY2 AS DOUBLE
    DIM i AS INTEGER

    sumX = 0.0 : sumY = 0.0 : sumXY = 0.0 : sumX2 = 0.0 : sumY2 = 0.0
    FOR i = 0 TO count - 1
        sumX = sumX + x(i)
        sumY = sumY + y(i)
        sumXY = sumXY + x(i) * y(i)
        sumX2 = sumX2 + x(i) * x(i)
        sumY2 = sumY2 + y(i) * y(i)
    NEXT i

    DIM n AS DOUBLE : n = count
    DIM denomX AS DOUBLE : denomX = n * sumX2 - sumX * sumX
    DIM denomY AS DOUBLE : denomY = n * sumY2 - sumY * sumY

    IF ABS(denomX) < MATH_EPSILON THEN
        slope = 0.0
        intercept = sumY / n
        rCoeff = 0.0
        EXIT SUB
    END IF

    slope = (n * sumXY - sumX * sumY) / denomX
    intercept = (sumY - slope * sumX) / n

    IF denomX > 0.0 AND denomY > 0.0 THEN
        rCoeff = (n * sumXY - sumX * sumY) / SQR(denomX * denomY)
    ELSE
        rCoeff = 0.0
    END IF
END SUB

' ------------------------------------------------------------------------------
' SECTION 5: DISCRETE KALMAN FILTER RECURSIVE ESTIMATOR
' ------------------------------------------------------------------------------

' DiscreteKalmanFilter: Updates state estimate x and covariance P given noisy measurement z
' State model: x_{k} = A * x_{k-1} + B * u_{k} + w_{k}
' Measurement: z_{k} = H * x_{k} + v_{k}
SUB DiscreteKalmanFilter(xEst AS DOUBLE, covP AS DOUBLE, measurement AS DOUBLE, controlIn AS DOUBLE, _
                         paramA AS DOUBLE, paramB AS DOUBLE, paramH AS DOUBLE, _
                         noiseQ AS DOUBLE, noiseR AS DOUBLE)
    ' 1. Time Update (Predict)
    DIM xPred AS DOUBLE
    DIM pPred AS DOUBLE
    xPred = paramA * xEst + paramB * controlIn
    pPred = paramA * covP * paramA + noiseQ

    ' 2. Measurement Update (Correct)
    DIM innovation AS DOUBLE
    DIM innovCov AS DOUBLE
    DIM kalmanGain AS DOUBLE

    innovation = measurement - paramH * xPred
    innovCov = paramH * pPred * paramH + noiseR
    kalmanGain = SafeDivide(pPred * paramH, innovCov, 0.0)

    xEst = xPred + kalmanGain * innovation
    covP = (1.0 - kalmanGain * paramH) * pPred
END SUB
