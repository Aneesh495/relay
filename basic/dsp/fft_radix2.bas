' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' In-Place Cooley-Tukey Radix-2 Fast Fourier Transform (FFT)
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/dsp/fft_radix2.bas
' ==============================================================================
'
' This module implements the in-place decimation-in-time (DIT) Cooley-Tukey
' Radix-2 Fast Fourier Transform for vibration condition monitoring:
'   - Discrete spectral analysis of rotating machinery (motors, pumps, turbines)
'   - Bit-reversal permutation array reordering
'   - Twiddle factor trigonometric evaluation: W_N^k = exp(-j * 2 * pi * k / N)
'   - In-place butterfly recombination across log2(N) stages
' ==============================================================================

CONST PI_CONST = 3.141592653589793

' BitReverseIndex: Computes bit-reversed integer for power-of-two size N
FUNCTION BitReverseIndex(idx AS INTEGER, numBits AS INTEGER) AS INTEGER
    DIM rev AS INTEGER : rev = 0
    DIM b AS INTEGER
    FOR b = 1 TO numBits
        rev = (rev * 2) + (idx AND 1)
        idx = idx / 2
    NEXT b
    BitReverseIndex = rev
END FUNCTION

' ComputeFftRadix2: In-place FFT of real and imaginary signal arrays (size N = 2^M)
SUB ComputeFftRadix2(realPart(512) AS DOUBLE, imagPart(512) AS DOUBLE, nSamples AS INTEGER, numBits AS INTEGER)
    IF nSamples <= 1 THEN EXIT SUB
    
    ' 1. Bit-Reversal Permutation
    DIM i AS INTEGER
    FOR i = 0 TO nSamples - 1
        DIM j AS INTEGER
        j = BitReverseIndex(i, numBits)
        IF j > i THEN
            ' Swap real components
            DIM tempR AS DOUBLE : tempR = realPart(i + 1)
            realPart(i + 1) = realPart(j + 1)
            realPart(j + 1) = tempR
            ' Swap imaginary components
            DIM tempI AS DOUBLE : tempI = imagPart(i + 1)
            imagPart(i + 1) = imagPart(j + 1)
            imagPart(j + 1) = tempI
        END IF
    NEXT i
    
    ' 2. Butterfly Computation Stages
    DIM stage AS INTEGER
    FOR stage = 1 TO numBits
        DIM lenSub AS INTEGER : lenSub = 1
        DIM s AS INTEGER
        FOR s = 1 TO stage : lenSub = lenSub * 2 : NEXT s
        
        DIM halfSub AS INTEGER : halfSub = lenSub / 2
        DIM angleStep AS DOUBLE : angleStep = -(2.0 * PI_CONST) / lenSub
        
        DIM kSub AS INTEGER
        FOR kSub = 0 TO nSamples - 1 STEP lenSub
            DIM wAngle AS DOUBLE : wAngle = 0.0
            DIM bFly AS INTEGER
            FOR bFly = 0 TO halfSub - 1
                DIM wr AS DOUBLE : wr = COS(wAngle)
                DIM wi AS DOUBLE : wi = SIN(wAngle)
                
                DIM idx1 AS INTEGER : idx1 = kSub + bFly + 1
                DIM idx2 AS INTEGER : idx2 = idx1 + halfSub
                
                ' Complex multiply: t = W * x[idx2]
                DIM tr AS DOUBLE : tr = wr * realPart(idx2) - wi * imagPart(idx2)
                DIM ti AS DOUBLE : ti = wr * imagPart(idx2) + wi * realPart(idx2)
                
                ' Butterfly recombination: x[idx2] = x[idx1] - t; x[idx1] = x[idx1] + t
                realPart(idx2) = realPart(idx1) - tr
                imagPart(idx2) = imagPart(idx1) - ti
                realPart(idx1) = realPart(idx1) + tr
                imagPart(idx1) = imagPart(idx1) + ti
                
                wAngle = wAngle + angleStep
            NEXT bFly
        NEXT kSub
    NEXT stage
END SUB

' ComputeMagnitudeSpectrum: Calculates absolute amplitude |X[k]| = sqrt(Re^2 + Im^2)
SUB ComputeMagnitudeSpectrum(realPart(512) AS DOUBLE, imagPart(512) AS DOUBLE, magnitude(512) AS DOUBLE, nSamples AS INTEGER)
    DIM k AS INTEGER
    FOR k = 1 TO nSamples
        magnitude(k) = SQR(realPart(k) * realPart(k) + imagPart(k) * imagPart(k))
    NEXT k
END SUB
