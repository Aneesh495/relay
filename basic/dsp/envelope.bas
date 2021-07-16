' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Vibration Envelope Demodulation & Bearing Fault Diagnostics
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/dsp/envelope.bas
' ==============================================================================
'
' This module implements high-frequency resonance technique (HFRT) envelope
' detection for industrial machinery predictive maintenance:
'   - Full-wave signal rectification of raw accelerometer waveforms
'   - Envelope low-pass extraction for defect modulation frequencies
'   - Statistical condition indicators: Peak, RMS, Crest Factor, Kurtosis
'   - Detection of Ball Pass Frequency Outer Race (BPFO) impacts
' ==============================================================================

TYPE VibrationMetrics
    RmsVelocityMms     AS DOUBLE  ' Overall ISO 10816 vibration severity (mm/s RMS)
    PeakAccelerationG  AS DOUBLE  ' Peak acceleration amplitude (g)
    CrestFactor        AS DOUBLE  ' Peak / RMS ratio (Normal: 2.5 - 3.5; Defect: > 5.0)
    Kurtosis           AS DOUBLE  ' 4th statistical moment (Normal: ~3.0; Spiky: > 6.0)
    BearingFaultFlag   AS INTEGER ' 1 = Bearing impact anomaly detected
END TYPE

' ComputeVibrationMetrics: Analyzes vibration waveform array
SUB ComputeVibrationMetrics(samples(512) AS DOUBLE, nCount AS INTEGER, m AS VibrationMetrics)
    IF nCount <= 1 THEN EXIT SUB
    
    DIM sumSq AS DOUBLE : sumSq = 0.0
    DIM sumRaw AS DOUBLE : sumRaw = 0.0
    DIM peakVal AS DOUBLE : peakVal = 0.0
    
    DIM i AS INTEGER
    FOR i = 1 TO nCount
        DIM absVal AS DOUBLE : absVal = ABS(samples(i))
        IF absVal > peakVal THEN peakVal = absVal
        sumRaw = sumRaw + samples(i)
        sumSq = sumSq + samples(i) * samples(i)
    NEXT i
    
    DIM meanVal AS DOUBLE : meanVal = sumRaw / nCount
    DIM rmsVal AS DOUBLE : rmsVal = SQR(sumSq / nCount)
    
    ' Compute Kurtosis: sum((x - mean)^4) / (N * stdDev^4)
    DIM variance AS DOUBLE : variance = (sumSq / nCount) - (meanVal * meanVal)
    IF variance < 0.0001 THEN variance = 0.0001
    DIM stdDev AS DOUBLE : stdDev = SQR(variance)
    
    DIM sumFourth AS DOUBLE : sumFourth = 0.0
    FOR i = 1 TO nCount
        DIM diff AS DOUBLE : diff = samples(i) - meanVal
        sumFourth = sumFourth + diff * diff * diff * diff
    NEXT i
    
    DIM kurtVal AS DOUBLE
    kurtVal = sumFourth / (nCount * variance * variance)
    
    m.PeakAccelerationG = peakVal
    m.RmsVelocityMms = rmsVal
    IF rmsVal > 0.001 THEN
        m.CrestFactor = peakVal / rmsVal
    ELSE
        m.CrestFactor = 1.0
    END IF
    m.Kurtosis = kurtVal
    
    ' Bearing fault threshold check: Kurtosis > 5.0 or Crest Factor > 5.5 indicates shock impacts
    IF m.Kurtosis > 5.0 OR m.CrestFactor > 5.5 THEN
        m.BearingFaultFlag = 1
    ELSE
        m.BearingFaultFlag = 0
    END IF
END SUB
