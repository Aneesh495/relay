' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Engineering Units Scaling & Sensor Linearization Library
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/tags/scaling.bas
' ==============================================================================
'
' This module implements industrial signal conditioning algorithms:
'   1. Linear ADC Count to Engineering Units Scaling
'   2. Differential Pressure (DP) Orifice Square Root Flow Extraction
'   3. RTD Resistance Linearization via Callendar-Van Dusen Equation
'   4. Polynomial Sensor Calibration Calibration Curves
' ==============================================================================

' Callendar-Van Dusen Coefficients for IEC 60751 Platinum RTDs (Pt100)
CONST RTD_R0_OHMS = 100.0        ' Nominal resistance at 0 deg C
CONST RTD_COEFF_A = 3.9083E-3    ' Alpha linear coefficient
CONST RTD_COEFF_B = -5.7750E-7   ' Beta quadratic coefficient

' ------------------------------------------------------------------------------
' SECTION 1: LINEAR SCALING ROUTINES
' ------------------------------------------------------------------------------

' ScaleLinearToEu: Converts raw ADC counts to engineering units
FUNCTION ScaleLinearToEu(raw AS DOUBLE, rawMin AS DOUBLE, rawMax AS DOUBLE, euMin AS DOUBLE, euMax AS DOUBLE) AS DOUBLE
    DIM spanRaw AS DOUBLE : spanRaw = rawMax - rawMin
    DIM spanEu AS DOUBLE : spanEu = euMax - euMin

    IF ABS(spanRaw) < 1.0E-9 THEN
        RETURN euMin
    END IF

    DIM frac AS DOUBLE : frac = (raw - rawMin) / spanRaw
    RETURN euMin + frac * spanEu
END FUNCTION

' ScaleEuToLinear: Converts engineering unit setpoint to raw DAC counts (e.g., 4-20mA)
FUNCTION ScaleEuToLinear(eu AS DOUBLE, euMin AS DOUBLE, euMax AS DOUBLE, rawMin AS DOUBLE, rawMax AS DOUBLE) AS DOUBLE
    DIM spanEu AS DOUBLE : spanEu = euMax - euMin
    DIM spanRaw AS DOUBLE : spanRaw = rawMax - rawMin

    IF ABS(spanEu) < 1.0E-9 THEN
        RETURN rawMin
    END IF

    DIM frac AS DOUBLE : frac = (eu - euMin) / spanEu
    DIM raw AS DOUBLE : raw = rawMin + frac * spanRaw
    RETURN ClampValue(raw, rawMin, rawMax)
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 2: SQUARE-ROOT ORIFICE PLATE FLOW SCALING
' ------------------------------------------------------------------------------

' ScaleSquareRootFlow: Converts differential pressure DP (in raw counts or mbar)
' to volumetric flow rate Q according to Bernoulli: Q = Q_max * SQR(DP / DP_max).
' Includes a low-flow cutoff threshold (e.g. 2% of span) to prevent square-root
' noise amplification near zero differential pressure.
FUNCTION ScaleSquareRootFlow(rawDp AS DOUBLE, rawMin AS DOUBLE, rawMax AS DOUBLE, _
                             maxFlow AS DOUBLE, lowCutoffPct AS DOUBLE) AS DOUBLE
    DIM spanRaw AS DOUBLE : spanRaw = rawMax - rawMin
    IF spanRaw <= 0.0 THEN RETURN 0.0

    DIM normDp AS DOUBLE : normDp = (rawDp - rawMin) / spanRaw
    IF normDp <= 0.0 THEN RETURN 0.0

    DIM cutoffFrac AS DOUBLE : cutoffFrac = lowCutoffPct * 0.01
    IF normDp < cutoffFrac THEN
        ' Below low-flow cutoff threshold, force output to zero
        RETURN 0.0
    END IF

    IF normDp > 1.0 THEN normDp = 1.0
    RETURN maxFlow * SQR(normDp)
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 3: RTD PT100 TEMPERATURE SENSOR LINEARIZATION
' ------------------------------------------------------------------------------

' ResistanceToTemperaturePt100: Calculates temperature in degrees Celsius from
' measured resistance (in Ohms) using the inverse Callendar-Van Dusen equation:
' R(T) = R0 * (1 + A*T + B*T^2)
' B*T^2 + A*T + (1 - R/R0) = 0
' Quadratic formula root: T = (-A + SQR(A^2 - 4*B*(1 - R/R0))) / (2*B)
FUNCTION ResistanceToTemperaturePt100(resistanceOhms AS DOUBLE) AS DOUBLE
    IF resistanceOhms < 18.52 THEN
        ' Sub-range below -200 deg C
        RETURN -200.0
    END IF

    DIM rRatio AS DOUBLE : rRatio = resistanceOhms / RTD_R0_OHMS
    DIM discriminant AS DOUBLE
    discriminant = RTD_COEFF_A * RTD_COEFF_A - 4.0 * RTD_COEFF_B * (1.0 - rRatio)

    IF discriminant < 0.0 THEN
        RETURN 850.0  ' Sensor over-range threshold
    END IF

    DIM tempDegC AS DOUBLE
    tempDegC = (-RTD_COEFF_A + SQR(discriminant)) / (2.0 * RTD_COEFF_B)
    RETURN tempDegC
END FUNCTION

' TemperatureToResistancePt100: Computes theoretical Pt100 resistance for given temperature
FUNCTION TemperatureToResistancePt100(tempDegC AS DOUBLE) AS DOUBLE
    DIM r AS DOUBLE
    IF tempDegC >= 0.0 THEN
        r = RTD_R0_OHMS * (1.0 + RTD_COEFF_A * tempDegC + RTD_COEFF_B * tempDegC * tempDegC)
    ELSE
        ' Cubic term for cryogenic temperatures below 0 deg C
        DIM cTerm AS DOUBLE : cTerm = -4.1830E-12
        r = RTD_R0_OHMS * (1.0 + RTD_COEFF_A * tempDegC + RTD_COEFF_B * tempDegC * tempDegC + _
                           cTerm * (tempDegC - 100.0) * tempDegC * tempDegC * tempDegC)
    END IF
    RETURN r
END FUNCTION

' ------------------------------------------------------------------------------
' SECTION 4: 3RD-ORDER CUBIC POLYNOMIAL CALIBRATION
' ------------------------------------------------------------------------------

' ScaleCubicCalibration: Evaluates 3rd-order sensor calibration curve:
' y = a0 + a1*x + a2*x^2 + a3*x^3
FUNCTION ScaleCubicCalibration(raw AS DOUBLE, a0 AS DOUBLE, a1 AS DOUBLE, a2 AS DOUBLE, a3 AS DOUBLE) AS DOUBLE
    DIM x2 AS DOUBLE : x2 = raw * raw
    DIM x3 AS DOUBLE : x3 = x2 * raw
    RETURN a0 + a1 * raw + a2 * x2 + a3 * x3
END FUNCTION
