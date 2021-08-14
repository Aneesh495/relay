# RELAY SCADA Operator & Console Interface Guide

This manual provides operating procedures for plant technicians, control room engineers, and operators running the RELAY SCADA and digital twin automation platform.

---

## 1. Process Control Faceplate Overview

RELAY renders standard industrial process faceplates compliant with EEMUA 191 and ANSI/ISA-101 human-machine interface guidelines directly inside ANSI color terminals.

### 1.1. Visual Hierarchy & Anatomical Layout

```
+--------------------------------------------------------------+
| LOOP: TIC-101     Reactor Temperature            [AUTO]      |
+--------------------------------------------------------------+
| PV:   311.26 deg C  [==========|.............]  42.5%        |
| SP:   315.00 deg C  [============|...........]  50.0%        |
| OP:    48.20 %      [===========|............]  48.2%        |
+--------------------------------------------------------------+
| ALARM: NORMAL       LL: 280.0  L: 295.0  H: 335.0  HH: 350.0 |
+--------------------------------------------------------------+
```

1. **Header Row**:
   - Loop Tag: Unique instrument identifier (e.g. `TIC-101`).
   - Description: Process function descriptor.
   - Operating Mode:
     - `[AUTO]`: Automatic closed-loop PID control.
     - `[MAN]`: Manual direct control of actuator output % by operator.
     - `[CAS]`: Cascade control; setpoint is dynamically governed by a master loop.

2. **Process Variable (PV) Bar**:
   - Numerical value and engineering units.
   - 24-character bargraph showing current position within transmitter calibrated span.
   - Vertical marker (`|`) indicates current setpoint target.

3. **Setpoint (SP) Bar**:
   - Operator or cascade target.

4. **Output (OP) Bar**:
   - Physical valve stroke or VFD frequency percentage (0.0% to 100.0%).

5. **Alarm Footer**:
   - Real-time status: `NORMAL`, `HIGH`, `HI-HI`, `LOW`, `LO-LO`, `ROC`.
   - Active alarm trip limits for rapid situational awareness.

---

## 2. ISA-18.2 Alarm Summary Banner

The alarm banner maintains an active prioritized list of process anomalies:

```
================================================================================
 ACTIVE ALARM BANNER (ISA-18.2) | ACTIVE: 1 | UNACK: 1 | [! HORN SOUNDING !]
--------------------------------------------------------------------------------
 TIME     | PRIO | TAG        | TYPE  | VALUE   | LIMIT   | EU   | DESCRIPTION
----------+------+------------+-------+---------+---------+------+--------------
*14:32:05 | CRIT | RX201.TEMP | HI-HI |  352.40 |  350.00 | K    | Thermal Exotherm
================================================================================
```

### Alarm Priority Levels
- `CRIT` (Priority 1): Severe hazard; immediate trip risk or environmental release. Audible annunciator sounds continuously until acknowledged.
- `HIGH` (Priority 2): Process operating limit exceeded; operator intervention required within 5 minutes.
- `MED`  (Priority 3): Advisory warning; efficiency or quality degradation.
- `LOW`  (Priority 4): Event notification; log for maintenance record.

The asterisk (`*`) indicates an unacknowledged alarm requiring operator acknowledgement.

---

## 3. Interactive SCADA Command Shell Reference

The interactive SCADA console allows real-time interrogation and intervention:

```
RELAY> HELP
```

### Available Commands

| Command | Arguments | Description | Example |
| :--- | :--- | :--- | :--- |
| `READ` | `<tag_identifier>` | Displays current value, engineering units, quality status, and timestamp. | `READ TK101.LEVEL` |
| `WRITE` | `<tag_identifier> <value>` | Overrides setpoint (in AUTO) or valve output % (in MAN). | `WRITE PUMP1.SPEED 45.0` |
| `MODE` | `<loop_tag> <AUTO\|MAN\|CAS>` | Transitions PID loop between Automatic, Manual, or Cascade mode. | `MODE TIC-101 MAN` |
| `ACK` | None | Acknowledges all active alarms and silences the audible annunciator horn. | `ACK` |
| `STATUS` | None | Generates health summary of controllers, scan cycle jitter, and historian buffer depth. | `STATUS` |
| `TREND` | `<tag_identifier>` | Renders a terminal ASCII historical trend chart of recent scans. | `TREND RX201.TEMP` |
| `QUIT` | None | Exits the interactive console shell. | `QUIT` |

---

## 4. Emergency Procedures

### 4.1. Emergency Stop (ESD) Activation
In the event of an uncontrolled process condition:
1. Type `WRITE ESD.TRIGGER 1` or engage the field emergency pushbutton.
2. The 16x16 Cause & Effect matrix immediately de-energizes all fail-safe safety valves (SDV), opens flare blowdown valves (BDV), and trips pump motors.
3. Once the process is stable and all physical sensors return to normal, the operator enters `WRITE ESD.RESET 1` to clear latched safety interlocks.
