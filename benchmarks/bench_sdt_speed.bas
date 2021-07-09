' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Benchmark Suite: Swinging Door Trending (SDT) Compression Throughput
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: benchmarks/bench_sdt_speed.bas
' ==============================================================================
'
' This benchmark evaluates the real-time telemetry compression throughput
' of the Swinging Door Trending (SDT) historian algorithm:
'   - Online geometric door slope updates
'   - Upper and lower slope divergence checks
'   - Benchmark target: 500,000 streaming telemetry samples
' ==============================================================================

PRINT "================================================================================"
PRINT "BENCHMARK: 500,000 SAMPLES SWINGING DOOR TRENDING (SDT) COMPRESSION"
PRINT "================================================================================"

DIM startMs AS DOUBLE : startMs = CLOCK_MS()

DIM sampleCount AS INTEGER : sampleCount = 500000
DIM compDev AS DOUBLE : compDev = 0.25
DIM archivedCount AS INTEGER : archivedCount = 0

DIM lastArchivedTime AS DOUBLE : lastArchivedTime = 0.0
DIM lastArchivedVal AS DOUBLE : lastArchivedVal = 100.0

DIM maxSlopeUpper AS DOUBLE : maxSlopeUpper = 1.0E9
DIM minSlopeLower AS DOUBLE : minSlopeLower = -1.0E9

DIM simTime AS DOUBLE : simTime = 0.0
DIM simVal AS DOUBLE : simVal = 100.0
DIM i AS INTEGER

FOR i = 1 TO sampleCount
    simTime = simTime + 0.1
    ' Synthetic slow drift with periodic noise
    simVal = 100.0 + 5.0 * SIN(simTime * 0.01) + (i MOD 7) * 0.02
    
    DIM dt AS DOUBLE : dt = simTime - lastArchivedTime
    IF dt > 0.0001 THEN
        DIM sUpper AS DOUBLE : sUpper = (simVal - lastArchivedVal + compDev) / dt
        DIM sLower AS DOUBLE : sLower = (simVal - lastArchivedVal - compDev) / dt
        
        IF sUpper < maxSlopeUpper THEN maxSlopeUpper = sUpper
        IF sLower > minSlopeLower THEN minSlopeLower = sLower
        
        ' Check if doors crossed (upper door slope dropped below lower door slope)
        IF maxSlopeUpper < minSlopeLower THEN
            archivedCount = archivedCount + 1
            lastArchivedTime = simTime
            lastArchivedVal = simVal
            maxSlopeUpper = 1.0E9
            minSlopeLower = -1.0E9
        END IF
    END IF
NEXT i

DIM endMs AS DOUBLE : endMs = CLOCK_MS()
DIM elapsedMs AS DOUBLE : elapsedMs = endMs - startMs
IF elapsedMs <= 0.0 THEN elapsedMs = 1.0

DIM samplesPerSec AS DOUBLE : samplesPerSec = (sampleCount * 1000.0) / elapsedMs
DIM compRatio AS DOUBLE
IF archivedCount > 0 THEN
    compRatio = (sampleCount * 1.0) / archivedCount
ELSE
    compRatio = 1.0
END IF

PRINT "BENCHMARK RESULTS:"
PRINT "   Total Raw Samples Processed : "; sampleCount
PRINT "   Archived Filtered Points    : "; archivedCount
PRINT "   Data Compression Ratio      : "; compRatio; ":1 ("; (1.0 - (1.0 / compRatio)) * 100.0; "% reduction)"
PRINT "   Total Elapsed Time          : "; elapsedMs; " ms"
PRINT "   Compression Throughput      : "; samplesPerSec; " samples / sec"
PRINT "================================================================================"
