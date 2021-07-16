' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Spectral Windowing Functions for Signal Leakage Suppression
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/dsp/windowing.bas
' ==============================================================================
'
' This module implements standard spectral windowing taper functions
' to mitigate spectral leakage in discrete Fourier transform processing:
'   - Hann (Hanning): 31.5 dB sidelobe rejection
'   - Hamming: 42.7 dB sidelobe rejection
'   - Blackman: 58.1 dB sidelobe rejection
'   - Flat-Top: Precision amplitude calibration window
' ==============================================================================

CONST DSP_PI = 3.141592653589793

' ApplyHanningWindow: w(n) = 0.5 - 0.5 * cos(2 * pi * n / (N - 1))
SUB ApplyHanningWindow(sig(512) AS DOUBLE, nSamples AS INTEGER)
    IF nSamples <= 1 THEN EXIT SUB
    DIM denom AS DOUBLE : denom = nSamples - 1.0
    DIM n AS INTEGER
    FOR n = 0 TO nSamples - 1
        DIM w AS DOUBLE
        w = 0.5 - 0.5 * COS((2.0 * DSP_PI * n) / denom)
        sig(n + 1) = sig(n + 1) * w
    NEXT n
END SUB

' ApplyHammingWindow: w(n) = 0.54 - 0.46 * cos(2 * pi * n / (N - 1))
SUB ApplyHammingWindow(sig(512) AS DOUBLE, nSamples AS INTEGER)
    IF nSamples <= 1 THEN EXIT SUB
    DIM denom AS DOUBLE : denom = nSamples - 1.0
    DIM n AS INTEGER
    FOR n = 0 TO nSamples - 1
        DIM w AS DOUBLE
        w = 0.54 - 0.46 * COS((2.0 * DSP_PI * n) / denom)
        sig(n + 1) = sig(n + 1) * w
    NEXT n
END SUB

' ApplyBlackmanWindow: 3-term cosine window
SUB ApplyBlackmanWindow(sig(512) AS DOUBLE, nSamples AS INTEGER)
    IF nSamples <= 1 THEN EXIT SUB
    DIM denom AS DOUBLE : denom = nSamples - 1.0
    DIM n AS INTEGER
    FOR n = 0 TO nSamples - 1
        DIM term1 AS DOUBLE : term1 = 0.5 * COS((2.0 * DSP_PI * n) / denom)
        DIM term2 AS DOUBLE : term2 = 0.08 * COS((4.0 * DSP_PI * n) / denom)
        DIM w AS DOUBLE : w = 0.42 - term1 + term2
        sig(n + 1) = sig(n + 1) * w
    NEXT n
END SUB
