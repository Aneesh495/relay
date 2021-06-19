' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' DNP3 (IEEE 1815) Telecontrol Link-Layer Dissector
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/protocols/dnp3_dissect.bas
' ==============================================================================
'
' This module implements frame synchronization and link-layer dissection for
' the DNP3 (Distributed Network Protocol / IEEE 1815) standard widely used in
' electrical power substations, water treatment utilities, and smart grids.
' ==============================================================================

CONST DNP3_SYNC_BYTE_1 = 5   ' 0x05
CONST DNP3_SYNC_BYTE_2 = 100 ' 0x64

' Dnp3LinkHeaderRecord: Decoded link-layer fields
TYPE Dnp3LinkHeaderRecord
    Length          AS INTEGER  ' Number of user octets following length byte
    ControlOctet    AS INTEGER  ' Direction, PRM, FCB, FCV, Function code
    DestAddress     AS INTEGER  ' 16-bit destination DNP3 station address
    SourceAddress   AS INTEGER  ' 16-bit source DNP3 master address
    HeaderCrc       AS INTEGER  ' 16-bit link header CRC
    IsValidSync     AS INTEGER  ' 1 if 0x0564 sync bytes match
END TYPE

' DissectDnp3LinkHeader: Parses raw octet stream into structured header
FUNCTION DissectDnp3LinkHeader(rawBytes(256) AS INTEGER, byteCount AS INTEGER, _
                               header AS Dnp3LinkHeaderRecord) AS INTEGER
    IF byteCount < 10 THEN
        header.IsValidSync = 0
        RETURN 0  ' Minimum DNP3 header length is 10 bytes
    END IF

    ' Check synchronization sync bytes 0x05 0x64
    IF rawBytes(0) <> DNP3_SYNC_BYTE_1 OR rawBytes(1) <> DNP3_SYNC_BYTE_2 THEN
        header.IsValidSync = 0
        RETURN 0
    END IF

    header.IsValidSync = 1
    header.Length = rawBytes(2)
    header.ControlOctet = rawBytes(3)
    header.DestAddress = rawBytes(4) + rawBytes(5) * 256
    header.SourceAddress = rawBytes(6) + rawBytes(7) * 256
    header.HeaderCrc = rawBytes(8) + rawBytes(9) * 256

    RETURN 1
END FUNCTION
