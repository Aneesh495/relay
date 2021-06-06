' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' In-Memory Circular Telemetry Buffer
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/historian/ring_buffer.bas
' ==============================================================================
'
' This module implements fixed-capacity circular ring buffers for high-frequency
' telemetry storage without dynamic memory allocations or GC pauses.
' ==============================================================================

CONST RING_CAPACITY = 1024

' TelemetryRingBuffer: In-memory fixed ring storage
TYPE TelemetryRingBuffer
    HeadIndex       AS INTEGER  ' Next write insertion slot
    TailIndex       AS INTEGER  ' Oldest available sample slot
    CurrentCount    AS INTEGER  ' Number of active records in buffer
    Times(1024)     AS DOUBLE   ' Millisecond timestamps
    Values(1024)    AS DOUBLE   ' Process values in engineering units
    Qualities(1024) AS INTEGER  ' OPC quality flags
END TYPE

' InitializeRingBuffer: Resets ring pointers
SUB InitializeRingBuffer(rb AS TelemetryRingBuffer)
    rb.HeadIndex = 0
    rb.TailIndex = 0
    rb.CurrentCount = 0
    DIM i AS INTEGER
    FOR i = 0 TO RING_CAPACITY - 1
        rb.Times(i) = 0.0
        rb.Values(i) = 0.0
        rb.Qualities(i) = 0
    NEXT i
END SUB

' PushRingSample: Appends a sample into the circular buffer
SUB PushRingSample(rb AS TelemetryRingBuffer, tsMs AS DOUBLE, val AS DOUBLE, q AS INTEGER)
    rb.Times(rb.HeadIndex) = tsMs
    rb.Values(rb.HeadIndex) = val
    rb.Qualities(rb.HeadIndex) = q

    rb.HeadIndex = (rb.HeadIndex + 1) MOD RING_CAPACITY
    IF rb.CurrentCount < RING_CAPACITY THEN
        rb.CurrentCount = rb.CurrentCount + 1
    ELSE
        ' Overwriting oldest sample: Advance tail pointer
        rb.TailIndex = (rb.TailIndex + 1) MOD RING_CAPACITY
    END IF
END SUB

' GetRingSampleAt: Retrieves logical sample by offset from oldest (0 = oldest)
FUNCTION GetRingSampleAt(rb AS TelemetryRingBuffer, offset AS INTEGER, tsMs AS DOUBLE, val AS DOUBLE, q AS INTEGER) AS INTEGER
    IF offset < 0 OR offset >= rb.CurrentCount THEN RETURN 0
    DIM actualIdx AS INTEGER
    actualIdx = (rb.TailIndex + offset) MOD RING_CAPACITY
    tsMs = rb.Times(actualIdx)
    val = rb.Values(actualIdx)
    q = rb.Qualities(actualIdx)
    RETURN 1
END FUNCTION
