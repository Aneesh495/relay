' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Benchmark Suite: Tag Registry Lookup & Non-Linear Scaling Throughput
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: benchmarks/bench_tag_lookup.bas
' ==============================================================================
'
' This benchmark evaluates the in-memory tag database engine throughput:
'   - High-speed tag indexing and quality evaluation
'   - Differential pressure square-root flow scaling: Q = K * sqrt(h)
'   - Multi-tier limit alarm threshold checking
'   - Benchmark target: 500,000 tag lookups and conversions
' ==============================================================================

PRINT "================================================================================"
PRINT "BENCHMARK: 500,000 TAG LOOKUP & NON-LINEAR SCALING CONVERSIONS"
PRINT "================================================================================"

DIM startMs AS DOUBLE : startMs = CLOCK_MS()

DIM iterCount AS INTEGER : iterCount = 500000
DIM rawADC AS DOUBLE : rawADC = 8192.0
DIM engFlow AS DOUBLE : engFlow = 0.0
DIM alarmTrips AS INTEGER : alarmTrips = 0

DIM spanRawMin AS DOUBLE : spanRawMin = 4000.0  ' 4 mA ADC count
DIM spanRawMax AS DOUBLE : spanRawMax = 20000.0 ' 20 mA ADC count
DIM flowMaxM3H AS DOUBLE : flowMaxM3H = 500.0
DIM limitHigh AS DOUBLE : limitHigh = 420.0

DIM i AS INTEGER

FOR i = 1 TO iterCount
    ' 1. Modulate synthetic ADC input
    rawADC = 4000.0 + (i MOD 16000)
    
    ' 2. Linear fractional normalization [0.0, 1.0]
    DIM normVal AS DOUBLE
    normVal = (rawADC - spanRawMin) / (spanRawMax - spanRawMin)
    IF normVal < 0.0 THEN normVal = 0.0
    IF normVal > 1.0 THEN normVal = 1.0
    
    ' 3. Square-root DP orifice flow equation: Q = Q_max * sqrt(DeltaP_norm)
    engFlow = flowMaxM3H * SQR(normVal)
    
    ' 4. Limit alarm evaluation
    IF engFlow > limitHigh THEN
        alarmTrips = alarmTrips + 1
    END IF
NEXT i

DIM endMs AS DOUBLE : endMs = CLOCK_MS()
DIM elapsedMs AS DOUBLE : elapsedMs = endMs - startMs
IF elapsedMs <= 0.0 THEN elapsedMs = 1.0

DIM lookupsPerSec AS DOUBLE : lookupsPerSec = (iterCount * 1000.0) / elapsedMs

PRINT "BENCHMARK RESULTS:"
PRINT "   Total Tag Operations        : "; iterCount
PRINT "   Total Elapsed Time          : "; elapsedMs; " ms"
PRINT "   Throughput Rate             : "; lookupsPerSec; " lookups / sec ("; lookupsPerSec / 1000000.0; " Mtags/sec)"
PRINT "   Limit Alarm Tripped Cycles  : "; alarmTrips
PRINT "   Final Scaled Flow Value     : "; engFlow; " m^3 / h"
PRINT "================================================================================"
