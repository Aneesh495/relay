' ==============================================================================
' RELAY INDUSTRIAL SCADA PLATFORM
' Equipment Permissives & 2-out-of-3 (2oo3) TMR Voting Logic
' Dialect: Dartmouth / ANSI Structured Modern BASIC
' File: basic/sequence/interlocks.bas
' ==============================================================================
'
' This module implements equipment safety permissives and Triple Modular
' Redundant (TMR) 2-out-of-3 (2oo3) voting logic. Prevents false plant trips
' caused by single instrument failures while guaranteeing fail-safe shutdown.
' ==============================================================================

' PermissiveCheckGroup: Represents a series of required start conditions
TYPE PermissiveCheckGroup
    ConditionCount      AS INTEGER
    ConditionStates(16) AS INTEGER  ' 1 if satisfied, 0 if unsatisfied
    AllPermissivesOk    AS INTEGER  ' 1 if equipment is cleared to start
END TYPE

' EvaluatePermissives: Checks if all interlock permissives are satisfied
FUNCTION EvaluatePermissives(grp AS PermissiveCheckGroup) AS INTEGER
    DIM i AS INTEGER
    FOR i = 0 TO grp.ConditionCount - 1
        IF grp.ConditionStates(i) = 0 THEN
            grp.AllPermissivesOk = 0
            RETURN 0
        END IF
    NEXT i
    grp.AllPermissivesOk = 1
    RETURN 1
END FUNCTION

' TwoOutOfThreeVotingResult: Output of 2oo3 TMR voting logic
TYPE TwoOutOfThreeVotingResult
    VotedTripCommand    AS INTEGER  ' 1 if 2 or 3 channels vote to trip
    ChannelDiscrepancy  AS INTEGER  ' 1 if one channel disagrees with the other two
    FaultyChannelIndex  AS INTEGER  ' Index of the outlier channel (0, 1, 2, or -1)
    MedianValue         AS DOUBLE   ' Mid-value process measurement
END TYPE

' Evaluate2oo3Voting: Solves 2-out-of-3 trip voting and identifies sensor drift
SUB Evaluate2oo3Voting(chA AS DOUBLE, chB AS DOUBLE, chC AS DOUBLE, _
                       tripLimit AS DOUBLE, isHighTrip AS INTEGER, _
                       result AS TwoOutOfThreeVotingResult)
    DIM tripA AS INTEGER : tripA = 0
    DIM tripB AS INTEGER : tripB = 0
    DIM tripC AS INTEGER : tripC = 0

    IF isHighTrip = 1 THEN
        IF chA >= tripLimit THEN tripA = 1
        IF chB >= tripLimit THEN tripB = 1
        IF chC >= tripLimit THEN tripC = 1
    ELSE
        IF chA <= tripLimit THEN tripA = 1
        IF chB <= tripLimit THEN tripB = 1
        IF chC <= tripLimit THEN tripC = 1
    END IF

    DIM tripCount AS INTEGER : tripCount = tripA + tripB + tripC

    ' 2oo3 Voting Rule: Trip if at least 2 channels vote yes
    IF tripCount >= 2 THEN
        result.VotedTripCommand = 1
    ELSE
        result.VotedTripCommand = 0
    END IF

    ' Discrepancy Detection (Single sensor failure / outlier)
    IF tripCount = 1 THEN
        result.ChannelDiscrepancy = 1
        IF tripA = 1 THEN result.FaultyChannelIndex = 0
        IF tripB = 1 THEN result.FaultyChannelIndex = 1
        IF tripC = 1 THEN result.FaultyChannelIndex = 2
    ELSEIF tripCount = 2 THEN
        result.ChannelDiscrepancy = 1
        IF tripA = 0 THEN result.FaultyChannelIndex = 0
        IF tripB = 0 THEN result.FaultyChannelIndex = 1
        IF tripC = 0 THEN result.FaultyChannelIndex = 2
    ELSE
        result.ChannelDiscrepancy = 0
        result.FaultyChannelIndex = -1
    END IF

    ' Compute Median Value (Middle of the 3 channels)
    IF (chA >= chB AND chA <= chC) OR (chA <= chB AND chA >= chC) THEN
        result.MedianValue = chA
    ELSEIF (chB >= chA AND chB <= chC) OR (chB <= chA AND chB >= chC) THEN
        result.MedianValue = chB
    ELSE
        result.MedianValue = chC
    END IF
END SUB
