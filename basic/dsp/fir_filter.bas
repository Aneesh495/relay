' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Finite Impulse Response (FIR) Digital Filter & Online Convolution
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/dsp/fir_filter.bas
' ==============================================================================
'
' This module implements digital FIR filtering with linear phase response:
'   - Sinc impulse response windowed low-pass design
'   - Real-time sample-by-sample tapped delay line convolution
'   - Zero phase distortion across passband frequencies
' ==============================================================================

CONST MAX_FIR_TAPS = 64

TYPE FirFilterInstance
    Taps(64)        AS DOUBLE  ' Filter impulse response coefficients b_k
    NumTaps         AS INTEGER ' Filter order + 1 (e.g. 17, 31 taps)
    DelayLine(64)   AS DOUBLE  ' Circular history state buffer
    BufferIndex     AS INTEGER
END TYPE

' InitializeFirFilter: Configures tapped delay line
SUB InitializeFirFilter(fir AS FirFilterInstance, tapCount AS INTEGER)
    IF tapCount > MAX_FIR_TAPS THEN tapCount = MAX_FIR_TAPS
    IF tapCount < 3 THEN tapCount = 3
    fir.NumTaps = tapCount
    fir.BufferIndex = 0
    
    DIM i AS INTEGER
    FOR i = 1 TO MAX_FIR_TAPS
        fir.Taps(i) = 1.0 / tapCount ' Default to moving average boxcar
        fir.DelayLine(i) = 0.0
    NEXT i
END SUB

' StepFirFilter: Evaluates single sample through tapped delay line convolution
FUNCTION StepFirFilter(fir AS FirFilterInstance, inputSample AS DOUBLE) AS DOUBLE
    ' Insert into circular buffer
    fir.DelayLine(fir.BufferIndex + 1) = inputSample
    
    ' Linear convolution sum: y[n] = sum(b_k * x[n-k])
    DIM sumVal AS DOUBLE : sumVal = 0.0
    DIM k AS INTEGER
    FOR k = 0 TO fir.NumTaps - 1
        DIM readIdx AS INTEGER
        readIdx = (fir.BufferIndex - k + fir.NumTaps) MOD fir.NumTaps
        sumVal = sumVal + fir.Taps(k + 1) * fir.DelayLine(readIdx + 1)
    NEXT k
    
    ' Advance circular index
    fir.BufferIndex = (fir.BufferIndex + 1) MOD fir.NumTaps
    StepFirFilter = sumVal
END FUNCTION
