' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Exothermic CSTR Chemical Reactor Digital Twin Simulator
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sim/cstr_reactor.bas
' ==============================================================================
'
' This module implements the non-linear Continuous Stirred Tank Reactor (CSTR)
' with an irreversible, first-order exothermic reaction A -> B. Arrhenius reaction
' rate kinetics (k = k0 * exp(-E / (R*T))) model thermal runaway and multiple
' steady-state equilibria.
' ==============================================================================

' CstrReactorState: Chemical kinetics, reactor dimensions, and state variables
TYPE CstrReactorState
    ' State Variables
    ConcentrationA  AS DOUBLE  ' Reactant A concentration Ca (mol / L)
    TemperatureK    AS DOUBLE  ' Reactor mixture temperature T (Kelvin)
    JacketTempK     AS DOUBLE  ' Cooling jacket coolant temperature Tc (Kelvin)

    ' Process Operating Parameters
    ReactorVolumeL  AS DOUBLE  ' Working liquid volume V (liters)
    FeedFlowRateLMin AS DOUBLE ' Process volumetric feed flow q (L / min)
    FeedConcA       AS DOUBLE  ' Feed stream reactant concentration Caf (mol / L)
    FeedTempK       AS DOUBLE  ' Feed stream temperature Tf (Kelvin)

    ' Coolant Jacket Parameters
    JacketVolumeL   AS DOUBLE  ' Cooling jacket volume Vc (liters)
    CoolantFlowLMin AS DOUBLE  ' Coolant volumetric flow qc (L / min)
    CoolantFeedTempK AS DOUBLE ' Coolant supply temperature Tcf (Kelvin)

    ' Kinetic and Thermodynamic Constants
    PreExpFactorK0  AS DOUBLE  ' Arrhenius pre-exponential factor k0 (min^-1)
    ActivationOverR AS DOUBLE  ' E / R activation energy ratio (Kelvin)
    HeatOfReactionDeltaH AS DOUBLE ' Heat of reaction -Delta H (cal / mol)
    HeatTransferUA  AS DOUBLE  ' Overall jacket heat transfer coeff UA (cal / (min * K))
    VolumetricHeatCapacity AS DOUBLE ' rho * Cp (cal / (L * K))
END TYPE

' InitializeCstrReactor: Sets standard Seborg/Edgar/Mellichamp chemical reactor constants
SUB InitializeCstrReactor(cstr AS CstrReactorState)
    cstr.ConcentrationA = 0.0882    ' mol / L
    cstr.TemperatureK = 311.261     ' Kelvin (approx 38.1 deg C)
    cstr.JacketTempK = 292.0        ' Kelvin (approx 18.8 deg C)

    cstr.ReactorVolumeL = 100.0     ' Liters
    cstr.FeedFlowRateLMin = 100.0   ' L / min
    cstr.FeedConcA = 1.0            ' mol / L
    cstr.FeedTempK = 350.0          ' Kelvin

    cstr.JacketVolumeL = 20.0       ' Liters
    cstr.CoolantFlowLMin = 100.0    ' L / min (Manipulated variable)
    cstr.CoolantFeedTempK = 350.0   ' Kelvin

    cstr.PreExpFactorK0 = 7.2E10    ' min^-1
    cstr.ActivationOverR = 8750.0   ' Kelvin (E / R)
    cstr.HeatOfReactionDeltaH = 5.0E4 ' cal / mol (Exothermic)
    cstr.HeatTransferUA = 5.0E4     ' cal / (min * K)
    cstr.VolumetricHeatCapacity = 1000.0 ' cal / (L * K)
END SUB

' StepCstrReactorEuler: Advances chemical mass and energy balances by dtMin minutes
SUB StepCstrReactorEuler(cstr AS CstrReactorState, coolantFlowLMin AS DOUBLE, dtMin AS DOUBLE)
    IF dtMin <= 0.0 THEN EXIT SUB

    cstr.CoolantFlowLMin = ClampValue(coolantFlowLMin, 0.0, 300.0)

    ' 1. Arrhenius Reaction Rate Constant: k = k0 * exp(-E / (R*T))
    DIM kRate AS DOUBLE
    IF cstr.TemperatureK > 100.0 THEN
        kRate = cstr.PreExpFactorK0 * EXP(-cstr.ActivationOverR / cstr.TemperatureK)
    ELSE
        kRate = 0.0
    END IF

    ' 2. Component A Mass Balance:
    ' dCa/dt = (q / V) * (Caf - Ca) - k * Ca
    DIM dCa_dt AS DOUBLE
    dCa_dt = (cstr.FeedFlowRateLMin / cstr.ReactorVolumeL) * (cstr.FeedConcA - cstr.ConcentrationA) - _
             kRate * cstr.ConcentrationA

    ' 3. Reactor Energy Balance:
    ' dT/dt = (q / V) * (Tf - T) + ((-Delta H) / (rho*Cp)) * k * Ca + (UA / (V * rho * Cp)) * (Tc - T)
    DIM reactionHeatTerm AS DOUBLE
    reactionHeatTerm = (cstr.HeatOfReactionDeltaH / cstr.VolumetricHeatCapacity) * kRate * cstr.ConcentrationA

    DIM jacketHeatTerm AS DOUBLE
    jacketHeatTerm = (cstr.HeatTransferUA / (cstr.ReactorVolumeL * cstr.VolumetricHeatCapacity)) * _
                     (cstr.JacketTempK - cstr.TemperatureK)

    DIM dT_dt AS DOUBLE
    dT_dt = (cstr.FeedFlowRateLMin / cstr.ReactorVolumeL) * (cstr.FeedTempK - cstr.TemperatureK) + _
            reactionHeatTerm + jacketHeatTerm

    ' 4. Cooling Jacket Energy Balance:
    ' dTc/dt = (qc / Vc) * (Tcf - Tc) + (UA / (Vc * rho_c * Cpc)) * (T - Tc)
    DIM jacketTransferTerm AS DOUBLE
    jacketTransferTerm = (cstr.HeatTransferUA / (cstr.JacketVolumeL * cstr.VolumetricHeatCapacity)) * _
                         (cstr.TemperatureK - cstr.JacketTempK)

    DIM dTc_dt AS DOUBLE
    dTc_dt = (cstr.CoolantFlowLMin / cstr.JacketVolumeL) * (cstr.CoolantFeedTempK - cstr.JacketTempK) + _
             jacketTransferTerm

    ' Explicit integration
    cstr.ConcentrationA = cstr.ConcentrationA + dCa_dt * dtMin
    cstr.TemperatureK = cstr.TemperatureK + dT_dt * dtMin
    cstr.JacketTempK = cstr.JacketTempK + dTc_dt * dtMin

    ' Safety physical constraints
    cstr.ConcentrationA = ClampValue(cstr.ConcentrationA, 0.0, cstr.FeedConcA * 2.0)
    cstr.TemperatureK = ClampValue(cstr.TemperatureK, 250.0, 600.0)
    cstr.JacketTempK = ClampValue(cstr.JacketTempK, 250.0, 600.0)
END SUB
