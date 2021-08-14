# Mathematical Process Control & Dynamic Modeling Theory

This document provides rigorous mathematical derivations and discrete implementations of the advanced regulatory control algorithms, autotuning methods, and non-linear digital twin differential equations implemented in RELAY.

---

## 1. The Standard ISA PID Algorithm

### 1.1. Continuous Ideal & Standard ISA Forms

The ideal continuous-time Proportional-Integral-Derivative equation is defined as:

$$u(t) = K_p \left[ e_P(t) + \frac{1}{T_i} \int_0^t e(\tau) d\tau + T_d \frac{de_D(t)}{dt} \right] + u_{bias}$$

where:
- $K_p$ is the proportional controller gain.
- $T_i$ is the integral reset time constant (seconds).
- $T_d$ is the derivative time constant (seconds).
- $u_{bias}$ is the feedforward baseline output (typically 50%).

To eliminate derivative kick (an infinite impulse response caused by step setpoint adjustments), the derivative term operates on the negative rate of change of the measured Process Variable ($PV$) rather than error:

$$e_D(t) = -PV(t)$$

Furthermore, setpoint weighting factor $\beta \in [0, 1]$ is applied to the proportional channel to soften closed-loop setpoint tracking without compromising disturbance rejection:

$$e_P(t) = \beta \cdot SP(t) - PV(t)$$

### 1.2. Discrete Velocity (Incremental) Formulation

In digital control computers, the incremental (velocity) algorithm calculates the difference $\Delta u_k = u_k - u_{k-1}$ at each discrete sample instant $k$ with sample interval $\Delta t$:

$$\Delta u_k = K_p \left[ (\beta \cdot SP_k - PV_k) - (\beta \cdot SP_{k-1} - PV_{k-1}) \right] + \frac{K_p \cdot \Delta t}{T_i} (SP_k - PV_k) - \frac{K_p \cdot T_d}{\Delta t} (PV_k - 2 PV_{k-1} + PV_{k-2})$$

$$u_k = u_{k-1} + \Delta u_k$$

The velocity form possesses intrinsic bumpless transfer characteristics: if the loop is switched between Manual and Automatic modes, $u_{k-1}$ is initialized to the current manual valve position, resulting in $\Delta u_0 = 0$ and zero actuator bump.

### 1.3. Integrator Anti-Windup Mechanics

When a physical actuator (e.g. control valve or VFD) saturates at its mechanical limits $[U_{min}, U_{max}]$, continued error integration leads to integrator windup, causing prolonged overshoot during setpoint recovery.

RELAY implements two anti-windup architectures:

1. **Conditional Integration (Clamping)**:
   The integrator accumulation is halted whenever the unconstrained output exceeds limits and the sign of the error would push the output further into saturation:
   $$\text{If } u_k \ge U_{max} \text{ and } e_k > 0 \implies \frac{dI}{dt} = 0$$
   $$\text{If } u_k \le U_{min} \text{ and } e_k < 0 \implies \frac{dI}{dt} = 0$$

2. **Back-Calculation (Tracking Time Constant $T_t$)**:
   The difference between the unconstrained output $v(t)$ and the saturated output $u(t)$ is fed back to the integrator with tracking rate $1 / T_t$:
   $$\frac{dI(t)}{dt} = \frac{K_p}{T_i} e(t) + \frac{1}{T_t} \left[ u(t) - v(t) \right]$$
   where $T_t \approx \sqrt{T_i \cdot T_d}$ provides optimal desaturation dynamics.

---

## 2. Astrom-Hagglund Relay Autotuning

RELAY implements non-parametric relay feedback autotuning (developed by Karl Johan Astrom and Tore Hagglund). Instead of manual step testing, a non-linear relay with hysteresis is temporarily inserted into the feedback loop.

### 2.1. Describing Function Derivation

When the system oscillates in a stable limit cycle with amplitude $a$ and period $T_u$, the relay output $u(t)$ is a square wave of amplitude $d$. The fundamental Fourier series component of this square wave is:

$$u_1(t) = \frac{4 d}{\pi} \sin(\omega_u t)$$

The equivalent complex describing function $N(a)$ of the relay without hysteresis is:

$$N(a) = \frac{4 d}{\pi a}$$

At the limit cycle oscillation frequency $\omega_u = 2\pi / T_u$, the open-loop Nyquist condition requires:

$$G(j \omega_u) N(a) = -1 \implies G(j \omega_u) = -\frac{1}{N(a)} = -\frac{\pi a}{4 d}$$

Therefore, the ultimate critical gain $K_u$ and ultimate period $T_u$ are extracted directly without driving the plant to instability:

$$K_u = \frac{4 d}{\pi a}$$
$$T_u = \text{Measured limit cycle period (seconds)}$$

### 2.2. Tyreus-Luyben Parameter Synthesis

For chemical processes with significant lag, RELAY synthesizes conservative Tyreus-Luyben PID settings designed for low oscillatory overshoot:

$$K_p = \frac{K_u}{2.2}$$
$$T_i = 2.2 \cdot T_u$$
$$T_d = \frac{T_u}{6.3}$$

---

## 3. Dynamic Digital Twin Process Models

### 3.1. Johansson Quadruple-Tank Benchmark

The process comprises four cross-connected liquid tanks fed by two variable-speed pumps:

$$\frac{dh_1}{dt} = -\frac{a_1}{A_1} \sqrt{2 g h_1} + \frac{a_3}{A_1} \sqrt{2 g h_3} + \frac{\gamma_1 k_1}{A_1} v_1$$

$$\frac{dh_2}{dt} = -\frac{a_2}{A_2} \sqrt{2 g h_2} + \frac{a_4}{A_2} \sqrt{2 g h_4} + \frac{\gamma_2 k_2}{A_2} v_2$$

$$\frac{dh_3}{dt} = -\frac{a_3}{A_3} \sqrt{2 g h_3} + \frac{(1 - \gamma_2) k_2}{A_3} v_2$$

$$\frac{dh_4}{dt} = -\frac{a_4}{A_4} \sqrt{2 g h_4} + \frac{(1 - \gamma_1) k_1}{A_4} v_1$$

The transfer function matrix $G(s)$ exhibits a multivariable transmission zero at:

$$z = \frac{1}{\gamma_1 + \gamma_2 - 1} \left( \frac{\gamma_1}{T_1} + \frac{\gamma_2}{T_2} \right)$$

- When $1 < \gamma_1 + \gamma_2 \le 2$, the zero is in the left-half complex plane (Minimum Phase).
- When $0 < \gamma_1 + \gamma_2 < 1$, the zero crosses into the right-half plane (Non-Minimum Phase), imposing fundamental performance limitations on multivariable feedback.

### 3.2. Exothermic CSTR Reactor (Arrhenius Kinetics)

A Continuous Stirred Tank Reactor carrying out an irreversible, first-order exothermic reaction $A \rightarrow B$:

**Arrhenius Reaction Velocity**:
$$k(T) = k_0 \exp\left( -\frac{E}{R \cdot T} \right)$$

**Component A Mass Balance**:
$$\frac{dC_A}{dt} = \frac{q}{V} (C_{Af} - C_A) - k(T) \cdot C_A$$

**Reactor Thermal Energy Balance**:
$$\frac{dT}{dt} = \frac{q}{V} (T_f - T) + \frac{-\Delta H}{\rho C_p} k(T) C_A + \frac{U A}{V \rho C_p} (T_c - T)$$

**Cooling Jacket Dynamic Energy Balance**:
$$\frac{dT_c}{dt} = \frac{q_c}{V_c} (T_{cf} - T_c) + \frac{U A}{V_c \rho_c C_{pc}} (T - T_c)$$

The non-linear exponential Arrhenius term creates multiple steady states and thermal runaway potential, providing an authentic benchmark for cascade cooling and SIS emergency shutdown interlocks.
