# Industrial Communication Protocols & Frame Specifications

RELAY implements six major industrial SCADA and fieldbus communication protocols in native bytecode and Structured BASIC. This document details their framing structures, byte layouts, checksum polynomials, and function dispatch mechanics.

---

## 1. Modbus TCP & Modbus RTU (IEC 61158)

Modbus is the foundational open serial protocol for industrial automation. RELAY supports both Ethernet TCP and RS-485 serial RTU framing.

### 1.1. Modbus TCP MBAP Header

The Modbus Application Protocol (MBAP) header prefixes every TCP Application Data Unit (ADU):

```
+-------------------+-------------------+-------------------+---------+
| Transaction ID    | Protocol ID (0)   | Length (Bytes)    | Unit ID |
| 2 Bytes (MSB 1st) | 2 Bytes (MSB 1st) | 2 Bytes (MSB 1st) | 1 Byte  |
+-------------------+-------------------+-------------------+---------+
```

- **Transaction Identifier**: Matches asynchronous request/response pairs.
- **Protocol Identifier**: Always `0x0000` for standard Modbus.
- **Length**: Number of following bytes, including the Unit Identifier and PDU.
- **Unit Identifier**: Slave / field drop address (1 to 247).

### 1.2. Modbus RTU CRC-16 Calculation

Modbus RTU frames on RS-485 serial links append a 16-bit Cyclic Redundancy Check (CRC-16).
- **Generator Polynomial**: $X^{16} + X^{15} + X^2 + 1$ (Reversed: `0xA001`).
- **Initial Preset**: `0xFFFF`.
- **Transmission Order**: Low-Order Byte first, followed by High-Order Byte.

```basic
FUNCTION ComputeModbusCRC16(buffer(256) AS INTEGER, length AS INTEGER) AS INTEGER
    DIM crc AS INTEGER : crc = 65535
    DIM i AS INTEGER : DIM b AS INTEGER
    FOR i = 1 TO length
        crc = crc XOR (buffer(i) AND 255)
        FOR b = 1 TO 8
            IF (crc AND 1) <> 0 THEN
                crc = ((crc / 2) AND 32767) XOR 40961 ' 0xA001
            ELSE
                crc = (crc / 2) AND 32767
            END IF
        NEXT b
    NEXT i
    ComputeModbusCRC16 = crc
END FUNCTION
```

### 1.3. IEEE-754 32-Bit Float Word Swapping

Process values like flow, temperature, and pressure are encoded as 32-bit single-precision IEEE-754 floating point numbers mapped across two consecutive 16-bit Modbus registers ($R_1, R_2$). Manufacturers differ in word and byte endianness:

1. **Big-Endian (Motorola / Standard)**: High-Word first, High-Byte first (`AB CD`).
2. **Little-Endian (Intel)**: Low-Word first, Low-Byte first (`DC BA`).
3. **Mid-Big (Byte-Swapped Big-Endian)**: High-Word first, Low-Byte first (`BA DC`).
4. **Mid-Little (Word-Swapped Big-Endian)**: Low-Word first, High-Byte first (`CD AB`).

RELAY provides bidirectional word-swapping transformers (`PackFloat32ToModbusRegisters` and `UnpackModbusRegistersToFloat32`) supporting all four conventions.

---

## 2. IEEE 1815 DNP3 (Distributed Network Protocol)

DNP3 is the prevailing telemetry protocol for electrical substations and water distribution utilities.

### 2.1. Link Layer Frame Structure

Every DNP3 frame begins with a fixed 10-byte header:

```
+-----------+---------------+--------+---------+---------+---------+
| Sync 0x05 | Sync 0x64     | Length | Control | Dest    | Source  |
| 1 Byte    | 1 Byte        | 1 Byte | 1 Byte  | 2 Bytes | 2 Bytes |
+-----------+---------------+--------+---------+---------+---------+
| Header CRC-16 (2 Bytes)   | Data Chunks + 16-bit CRCs every 16 B |
+---------------------------+--------------------------------------+
```

- **Sync Octets**: Always `0x05` followed by `0x64`.
- **Length**: Number of octets following the Length octet up to the end of the frame, excluding CRC octets.
- **Control Byte**: Contains DIR (Direction), PRM (Primary message), FCB (Frame count bit), and FCV (Frame count valid).
- **CRC-16 Polynomial**: `0xA653` with ones-complement inversion.

---

## 3. Sparkplug B (MQTT Edge-to-Cloud)

Sparkplug B specifies how industrial edge nodes encode and compress real-time telemetry over MQTT brokers.

### 3.1. Topic Namespace Format

```
spBv1.0 / {group_id} / {message_type} / {edge_node_id} / [{device_id}]
```

- **Group ID**: Logical plant area or physical site (e.g. `RefineryNorth`).
- **Message Type**:
  - `NBIRTH`: Node birth announcement containing all published metrics.
  - `NDATA`: Incremental node telemetry changes (report-by-exception).
  - `NDEATH`: Unclean disconnection will testament.
  - `DBIRTH` / `DDATA`: Attached field device birth and data streams.
- **Sequence Counter**: Integer between 0 and 255. Increments by 1 on every published frame, rolling over from 255 to 0. A dropped sequence number flags packet loss.

---

## 4. HART FSK Bell 202

HART layers 1200 baud digital bidirectional communications simultaneously over standard 4-20 mA analog current loops using Bell 202 Frequency Shift Keying (1200 Hz = Binary 1 / Mark; 2200 Hz = Binary 0 / Space).

### 4.1. Frame Format & Longitudinal Parity (LRC)

```
+-------------------+-----------+---------+---------+---------+------+-----+
| Preamble (0xFF x) | Delimiter | Address | Command | ByteCnt | Data | LRC |
| 5 to 20 Bytes     | 1 Byte    | 1 or 5B | 1 Byte  | 1 Byte  | 0..B | 1 B |
+-------------------+-----------+---------+---------+---------+------+-----+
```

- **Delimiter**: `0x02` (Master-to-Slave STX), `0x06` (Slave-to-Master ACK).
- **Address**: Short address (0 to 15 for point-to-point) or Long address (unique 38-bit manufacturer/device ID).
- **Checksum (LRC)**: Cumulative XOR of all bytes from Delimiter through the last Data byte.

---

## 5. OPC Unified Architecture (IEC 62541) Binary TCP

OPC UA Binary TCP is an optimized connection-oriented framing layer:

```
+-------------------+-------------------+-------------------+
| Message Type      | Chunk Type        | Message Size      |
| 3 Bytes (ASCII)   | 1 Byte ('F','C')  | 4 Bytes (LE uint) |
+-------------------+-------------------+-------------------+
| Secure Channel Header & Service Request / Response Payload|
+-----------------------------------------------------------+
```

- **Message Types**:
  - `HEL`: Hello client connection parameters (buffer sizes).
  - `ACK`: Acknowledge server response.
  - `OPN`: OpenSecureChannel asymmetric handshake.
  - `MSG`: Standard service calls (Read, Write, Browse).
  - `CLO`: CloseSecureChannel termination.
- **Chunk Types**: `F` (Final chunk), `C` (Continuation chunk), `A` (Abort chunk).

---

## 6. CANopen (CiA 301) Fieldbus

CANopen operates over 11-bit CAN 2.0A identifier headers (COB-IDs):

| Function Code (Bits 7..10) | Nominal COB-ID Range | Protocol Service |
| :--- | :--- | :--- |
| `0x000` | `0x000` | NMT Network Management Broadcast |
| `0x080` | `0x080` | SYNC Synchronization Frame |
| `0x180` | `0x181` to `0x1FF` | TPDO1 Transmit Process Data Object 1 |
| `0x200` | `0x201` to `0x27F` | RPDO1 Receive Process Data Object 1 |
| `0x580` | `0x581` to `0x5FF` | TSDO Transmit Service Data Object (Response) |
| `0x600` | `0x601` to `0x67F` | RSDO Receive Service Data Object (Request) |
| `0x700` | `0x701` to `0x77F` | NMT Heartbeat & Error Control |
