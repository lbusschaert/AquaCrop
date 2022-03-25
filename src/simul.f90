module ac_simul

use ac_kinds, only:  dp, &
                     int8, &
                     int32, &
                     intEnum


use ac_global, only: ActiveCells, &
                     adjustedksstotoecsw, &
                     CalculateETpot, &
                     CanopyCoverNoStressSF, &
                     CO2Ref, &
                     CompartmentIndividual, &
                     CropStressParametersSoilFertility, &
                     datatype_daily, &
                     datatype_decadely, &
                     datatype_monthly, &
                     DaySubmerged, &
                     DetermineCNIandIII, &
                     DetermineRootZoneSaltContent, &
                     DetermineRootzoneWC, &
                     ECeComp, &
                     ECswComp, &
                     EffectiveRainMethod_Percentage, &
                     EffectiveRainMethod_USDA, &
                     Equiv, &
                     EvapZmin, &
                     fAdjustedForCO2, &
                     fAdjustedForCO2, &
                     GenerateDepthMode_FixDepth, &
                     GenerateTimeMode_AllDepl, &
                     GenerateTimeMode_AllRAW, &
                     GetCompartment, &
                     getcompartment_dayanaero, &
                     GetCompartment_Depo, &
                     GetCompartment_FCadj, &
                     GetCompartment_fluxout, &
                     GetCompartment_i, &
                     GetCompartment_Layer, &
                     GetCompartment_Salt, &
                     GetCompartment_Smax, &
                     GetCompartment_theta, &
                     GetCompartment_Thickness, &
                     GetCompartment_WFactor, &
                     GetTact, &
                     GetTactWeedInfested, &
                     GetCrop, &
                     GetCrop_AdaptedToCO2, &
                     GetCrop_AnaeroPoint, &
                     GetCrop_CCEffectEvapLate, &
                     GetCrop_CCsaltDistortion, &
                     GetCrop_CCo, &
                     GetCrop_CCx, &
                     GetCrop_CGC, &
                     GetCrop_CDC, &
                     GetCrop_Day1, &
                     GetCrop_DayN, &
                     GetCrop_DaysToFlowering, &
                     GetCrop_DaysToFullCanopy, &
                     GetCrop_DaysToFullCanopySF, &
                     GetCrop_DaysToGermination, &
                     GetCrop_DaysToHarvest, &
                     GetCrop_DaysToSenescence, &
                     GetCrop_dHIdt, &
                     GetCrop_DeterminancyLinked, &
                     GetCrop_ECemin, &
                     GetCrop_ECemax, &
                     GetCrop_GDDCDC, &
                     GetCrop_GDDCGC, &
                     GetCrop_GDDLengthFlowering, &
                     getcrop_gddaystofullcanopy, &
                     getcrop_gddaystoflowering, &
                     getcrop_gddaystoharvest, &
                     getcrop_gddaystogermination, &
                     getcrop_gddaystosenescence, &
                     GetCrop_GDtranspLow, &
                     GetCrop_HI, &
                     GetCrop_KcDecline, &
                     GetCrop_KcTop, &
                     GetCrop_KsShapeFactorStomata, &
                     GetCrop_LengthFlowering, &
                     GetCrop_ModeCycle, &
                     GetCrop_pActStom, &
                     GetCrop_Planting, &
                     GetCrop_ResponseECsw, &
                     GetCrop_RootMin, &
                     GetCrop_Tbase, &
                     GetCrop_Tupper, &
                     GetCrop_pLeafDefLL, &
                     GetCrop_pLeafDefUL, &
                     GetCrop_pMethod, &
                     GetCrop_pSenescence, &
                     getsimulation_dayanaero, &
                     Getcrop_smaxbot, &
                     GetCrop_SmaxTop, &
                     GetCrop_StressResponse, &
                     GetCrop_subkind, &
                     GetCrop_Tbase, &
                     GetCrop_Tupper, &   
                     GetCrop_WP, &
                     GetCrop_WPy, &
                     GetDrain, &
                     GetEact, &
                     GetECdrain, &
                     GetECiAqua, &
                     GetECstorage, &
                     GetEpot, &
                     GetETO, &
                     GetEvapoEntireSoilSurface, &
                     GetGenerateDepthMode, &
                     GetGenerateTimeMode, &
                     GetIrriECw_PostSeason, &
                     GetIrriECw_PreSeason, &
                     GetIrrigation, &
                     GetIrriMode, &
                     GetManagement_BundHeight, &
                     GetManagement_CNcorrection, &
                     GetManagement_EffectMulchInS, &
                     GetManagement_EffectMulchOffS, &
                     GetManagement_FertilityStress, &
                     GetManagement_Mulch, &
                     GetManagement_SoilCoverAfter, &
                     GetManagement_SoilCoverBefore, &
                     GetNrCompartments, &
                     GetRain, &
                     GetRainRecord_DataType, &
                     GetRootingDepth, &
                     GetRootZoneSalt_ECe, &
                     GetRootZoneSalt_ECsw, &
                     GetRootZoneSalt_ECswFC, &
                     GetRootZoneSalt_KsSalt, &
                     GetRootZoneWC_Actual, &
                     GetRootZoneWC_FC, &
                     GetRootZoneWC_SAT, &
                     GetRootZoneWC_WP, &
                     GetRootZoneWC_Thresh, &
                     GetRootZoneWC_ZtopAct, &
                     GetRootZoneWC_ZtopFC, &
                     GetRootZoneWC_ZtopThresh, &
                     GetRootZoneWC_ZtopWP, &
                     GetRunoff, &
                     GetSimulation_DelayedDays, &
                     GetSimulParam_DelayLowOxygen, &
                     GetSimulParam_PercRAW, &
                     GetSimulation_EffectStress, &
                     GetSimulation_EffectSTress_RedCCx, &
                     GetSimulation_EffectStress_RedCGC, &
                     GetSimulation_EffectStress_RedKsSto, &
                     GetSimulation_EvapStartStg2, &
                     GetSimulation_EvapWCsurf, &
                     GetSimulation_EvapZ, &
                     GetSimulation_Germinate, &
                     GetSimulation_IrriECw, &
                     GetSimulation_SalinityConsidered, &
                     GetSimulation_SCor, &
                     GetSimulation_SWCtopSoilConsidered, &
                     GetSimulParam_TAWGermination, &
                     GetSimulParam_Beta, &
                     GetSimulParam_CNcorrection, &
                     GetSimulParam_EffectiveRain_Method, &
                     GetSimulParam_EffectiveRain_PercentEffRain, &
                     GetSimulParam_EffectiveRain_ShowersInDecade, &
                     GetSimulParam_EvapZmax, &
                     GetSimulParam_IniAbstract, &
                     GetSimulParam_IrriFwInSeason, &
                     GetSimulParam_IrriFwOffSeason, &
                     GetSimulParam_pAdjFAO, &
                     GetSimulParam_RootNrDF, &
                     GetSimulParam_SaltSolub, &
                     GetSimulParam_Tmax, &
                     GetSimulParam_Tmin, &
                     GetSoil, &
                     GetSoil_CNvalue, &
                     GetSoil_REW, &
                     GetSoil_NrSoilLayers, &
                     GetSoilLayer_CRa, &
                     GetSoilLayer_CRb, &
                     GetSoilLayer_Dx, &
                     GetSoilLayer_FC, &
                     GetSoilLayer_GravelVol, &
                     GetSoilLayer_InfRate, &
                     GetSoilLayer_SaltMobility_i, &
                     GetSoilLayer_SAT, &
                     GetSoilLayer_SC, &
                     GetSoilLayer_SCP1, &
                     GetSoilLayer_tau, &
                     GetSoilLayer_Thickness, &
                     GetSoilLayer_UL, &
                     GetSoilLayer_WP, &
                     GetSoilLayer_WaterContent, &
                     GetSurfaceStorage, &
                     GetTpot, &
                     GetTact, &
                     GetZiAqua, &
                     GetInfiltrated, &
                     GetSumWaBal_SaltOut, &
                     GetSumWaBal_SaltIn, &
                     GetSumWaBal_CRsalt, &
                     GetSumWaBal_ECropCycle, &
                     GetSumWaBal_Epot, &
                     GetSumWaBal_Tpot, &
                     GetSumWaBal_Rain, &
                     GetSumWaBal_Irrigation, &
                     GetSumWaBal_Drain, &
                     GetSumWaBal_Eact, &
                     GetSumWaBal_Runoff, &
                     GetSumWaBal_Infiltrated, &
                     GetSumWaBal_CRwater, &
                     GetSumWaBal_TrW, &
                     GetSumWaBal_Tact, &
                     GetSumWaBal_Biomass, &
                     GetCRsalt, &
                     GetCRwater, &
                     GetTotalWaterContent_BeginDay, &
                     GetTotalSaltContent_BeginDay, &
                     GetTotalWaterContent_EndDay, &
                     GetTotalSaltContent_EndDay, &
                     GetEact, &
                     GetCCiActual, &
                     IrriMode_Inet, &
                     KsAny, &
                     KsSalinity, &
                     max_No_compartments, &
                     MaxCRatDepth, &
                     modeCycle_CalendarDays, &
                     plant_seed, &
                     modeCycle_GDDays, &
                     pMethod_FAOCorrection, &
                     rep_Crop, &
                     rep_EffectStress, &
                     rep_Soil, &
                     roundc, &
                     SaltSolutionDeposit, &
                     SetCrop_pActStom, &
                     SetCompartment, &
                     SetCompartment_Depo, &
                     SetCompartment_fluxout, &
                     SetCompartment_i, &
                     SetCompartment_Salt, &
                     SetCompartment_theta, &
                     SetCompartment_WFactor, &
                     SetCompartment_DayAnaero, &
                     SetCrop_DaysTOFullCanopySF, &
                     SetCrop_GDDaysToFullCanopySF, &
                     SetDrain, &
                     SetEact, &
                     SetECdrain, &
                     SetECstorage, &
                     SetEvapoEntireSoilSurface, &
                     SetIrrigation, &
                     SetRootZoneSalt_ECe, &
                     SetRootZoneSalt_ECsw, &
                     SetRootZoneSalt_ECswFC, &
                     SetRootZoneSalt_KsSalt, &
                     SetRunoff, &
                     SetSimulation_DelayedDays, &
                     SetSimulation_Germinate, &
                     SetSimulation_ProtectedSeedling, &
                     setsimulation_sumgdd, &
                     SetSaltInfiltr, &
                     setsimulation_dayanaero, &
                     SetSimulation_EffectStress, &
                     SetSimulation_EffectStress_CDecline, &
                     SetSimulation_EffectStress_RedCCx, &
                     SetSimulation_EffectStress_RedCGC, &
                     SetSimulation_EffectStress_RedKsSto, &
                     SetSimulation_EffectStress_RedWP, &
                     SetSimulation_EvapStartStg2, &
                     SetSimulation_EvapWCsurf, &
                     SetSimulation_EvapZ, &
                     SetSimulation_SWCtopSoilConsidered, &
                     SetSurfaceStorage, &
                     SetTotalWaterContent_BeginDay, &
                     SetTotalSaltContent_BeginDay, & 
                     SetTotalWaterContent_EndDay, &
                     SetTotalSaltContent_EndDay, &
                     SetSoilLayer_WaterContent, &
                     SetTotalSaltContent_EndDay, &
                     SetTotalWaterContent_EndDay, &
                     SetTotalSaltContent_ErrorDay, &
                     SetTotalWaterContent_ErrorDay, &
                     SetInfiltrated, &
                     SetCRwater, &
                     SetCRsalt, &
                     SetSumWaBal_Epot, &
                     SetSumWaBal_Tpot, &
                     SetSumWaBal_Rain, &
                     SetSumWaBal_Irrigation, &
                     SetSumWaBal_Infiltrated, &
                     SetSumWaBal_Runoff, &
                     SetSumWaBal_Drain, &
                     SetSumWaBal_Eact, & 
                     SetSumWaBal_Tact, &
                     SetSumWaBal_TrW, &
                     SetSumWaBal_CRwater, &  
                     SetSumWaBal_ECropCycle, &
                     SetSumWaBal_SaltIn, &
                     SetSumWaBal_CRsalt, &
                     SetSumWaBal_SaltOut, &
                     SetTact, & 
                     subkind_Grain, &
                     subkind_Tuber, &
                     SurfaceStorage, &
                     TimeToMaxCanopySF, &
                     undef_int

                      
use ac_tempprocessing, only:    CropStressParametersSoilSalinity, &
                                GrowingDegreeDays, &
                                SumCalendarDays


implicit none

integer(intEnum), parameter :: whichtheta_AtSat = 0
    !! index of AtSat in whichtheta enumerated type
integer(intEnum), parameter :: whichtheta_AtFC = 1
    !! index of AtFC in whichtheta enumerated type
integer(intEnum), parameter :: whichtheta_AtWP = 2
    !! index of AtWP in whichtheta enumerated type
integer(intEnum), parameter :: whichtheta_AtAct = 3
    !! index of AtAct in whichtheta enumerated type


integer(intEnum), parameter :: control_begin_day = 0
    !! index of beginday in control enumerated type
integer(intEnum), parameter :: control_end_day = 1
    !! index of endday in control enumerated type


contains


real(dp) function GetCDCadjustedNoStressNew(CCx, CDC, CCxAdjusted)
    real(dp), intent(in) :: CCx
    real(dp), intent(in) :: CDC
    real(dp), intent(in) :: CCxAdjusted

    real(dp) :: CDCadjusted

    CDCadjusted = CDC * ((CCxadjusted+2.29_dp)/(CCx+2.29_dp))
    GetCDCadjustedNoStressNew = CDCadjusted

end function GetCDCadjustedNoStressNew

subroutine AdjustpLeafToETo(EToMean, pLeafULAct, pLeafLLAct)
    real(dp), intent(in) :: EToMean
    real(dp), intent(inout) :: pLeafULAct
    real(dp), intent(inout) :: pLeafLLAct


    pLeafLLAct = GetCrop_pLeafDefLL()
    pLeafULAct = GetCrop_pLeafDefUL()
    if (GetCrop_pMethod() == pMethod_FAOCorrection) then
        pLeafLLAct = GetCrop_pLeafDefLL() + GetSimulParam_pAdjFAO()* 0.04_dp &
                        *(5._dp-EToMean)*log10(10._dp-9._dp*GetCrop_pLeafDefLL())
        if (pLeafLLAct > 1.0) then
            pLeafLLAct = 1.0_dp
        end if
        if (pLeafLLAct < 0) then
            pLeafLLAct = 0._dp
        end if
        pLeafULAct = GetCrop_pLeafDefUL() + GetSimulParam_pAdjFAO()* 0.04_dp &
                        *(5._dp-EToMean)*log10(10._dp-9._dp*GetCrop_pLeafDefUL())
        if (pLeafULAct > 1.0) then
            pLeafULAct = 1.0_dp
        end if
        if (pLeafULAct < 0) then
            pLeafULAct = 0._dp
        end if
    end if
end subroutine AdjustpLeafToETo

subroutine DeterminePotentialBiomass(VirtualTimeCC, SumGDDadjCC, CO2i, GDDayi, &
                                              CCxWitheredTpotNoS, BiomassUnlim)
    integer(int32), intent(in) :: VirtualTimeCC
    real(dp), intent(in) :: SumGDDadjCC
    real(dp), intent(in) :: CO2i
    real(dp), intent(in) :: GDDayi
    real(dp), intent(inout) :: CCxWitheredTpotNoS
    real(dp), intent(inout) :: BiomassUnlim

    real(dp) :: CCiPot,  WPi, fSwitch, TpotForB, EpotTotForB
    integer(int32) :: DAP, DaysYieldFormation, DayiAfterFlowering
    real(dp) :: Tmin_local, Tmax_local

    ! potential biomass - unlimited soil fertiltiy
    ! 1. - CCi
    CCiPot = CanopyCoverNoStressSF((VirtualTimeCC + GetSimulation_DelayedDays() + 1), &
                                  GetCrop_DaysToGermination(), GetCrop_DaysToSenescence(), &
                                  GetCrop_DaysToHarvest(), GetCrop_GDDaysToGermination(), &
                                  GetCrop_GDDaysToSenescence(), GetCrop_GDDaysToHarvest(), &
                                  GetCrop_CCo(), GetCrop_CCx(), GetCrop_CGC(), &
                                  GetCrop_CDC(), GetCrop_GDDCGC(), GetCrop_GDDCDC(), &
                                  SumGDDadjCC, GetCrop_ModeCycle(), 0_int8, 0_int8)
    if (CCiPot < 0._dp) then
        CCiPot = 0._dp
    end if
    if (CCiPot > CCxWitheredTpotNoS) then
        CCxWitheredTpotNoS = CCiPot
    end if

    ! 2. - Calculation of Tpot
    if (GetCrop_ModeCycle() == modeCycle_CalendarDays) then
        DAP = VirtualTimeCC
    else
        ! growing degree days
        Tmin_local = GetSimulParam_Tmin()
        Tmax_local = GetSimulParam_Tmax()
        DAP = SumCalendarDays(roundc(SumGDDadjCC, mold=1), GetCrop_Day1(), GetCrop_Tbase(), &
                    GetCrop_Tupper(), Tmin_local, Tmax_local)
        DAP = DAP + GetSimulation_DelayedDays() ! are not considered when working with GDDays
    end if
    call CalculateETpot(DAP, GetCrop_DaysToGermination(), GetCrop_DaysToFullCanopy(), &
                   GetCrop_DaysToSenescence(), GetCrop_DaysToHarvest(), 0, CCiPot, &
                   GetETo(), GetCrop_KcTop(), GetCrop_KcDecline(), GetCrop_CCx(), &
                   CCxWitheredTpotNoS, real(GetCrop_CCEffectEvapLate(), kind=dp), CO2i, GDDayi, &
                   GetCrop_GDtranspLow(), TpotForB, EpotTotForB)

    ! 3. - WPi for that day
    ! 3a - given WPi
    WPi = (GetCrop_WP()/100._dp)
    ! 3b - WPi decline in reproductive stage  (works with calendar days)
    if (((GetCrop_subkind() == subkind_Grain) .or. (GetCrop_subkind() == subkind_Tuber)) &
        .and. (GetCrop_WPy() < 100._dp) .and. (GetCrop_dHIdt() > 0._dp) &
        .and. (VirtualTimeCC >= GetCrop_DaysToFlowering())) then
        ! WPi in reproductive stage
        fSwitch = 1._dp
        DaysYieldFormation = roundc(GetCrop_HI()/GetCrop_dHIdt(), mold=1)
        DayiAfterFlowering = VirtualTimeCC - GetCrop_DaysToFlowering()
        if ((DaysYieldFormation > 0) .and. (DayiAfterFlowering < &
                                              (DaysYieldFormation/3._dp))) then
            fSwitch = DayiAfterFlowering/(DaysYieldFormation/3._dp)
        end if
        WPi =  WPi * (1._dp - (1._dp-GetCrop_WPy()/100._dp)*fSwitch)
    end if
    ! 3c - adjustment WPi for CO2
    if (roundc(100._dp*CO2i, mold=1) /= roundc(100._dp*CO2Ref, mold=1)) then
        WPi = WPi * fAdjustedForCO2(CO2i, GetCrop_WP(), GetCrop_AdaptedToCO2())
    end if

    ! 4. - Potential Biomass
    if (GetETo() > 0._dp) then
        BiomassUnlim = BiomassUnlim + WPi * TpotForB/real(GetETo(), kind=dp) ! ton/ha
    end if

end subroutine DeterminePotentialBiomass


subroutine AdjustpSenescenceToETo(EToMean, TimeSenescence, WithBeta, pSenAct)
    real(dp), intent(in) :: EToMean
    real(dp), intent(in) :: TimeSenescence
    logical, intent(in) :: WithBeta
    real(dp), intent(inout) :: pSenAct

    pSenAct = GetCrop_pSenescence()
    if (GetCrop_pMethod() == pMethod_FAOCorrection) then
        pSenAct = GetCrop_pSenescence() + GetSimulParam_pAdjFAO() &
                            * 0.04_dp*(5._dp-EToMean) &
                            * log10(10._dp-9._dp*GetCrop_pSenescence())
        if ((TimeSenescence > 0.0001_dp) .and. WithBeta) then
            pSenAct = pSenAct * (1._dp-GetSimulParam_Beta()/100._dp)
        end if
        if (pSenAct < 0._dp) then
            pSenAct = 0._dp
        end if
        if (pSenAct >= 1.0_dp) then
            pSenAct = 0.98_dp ! otherwise senescence is not possible at WP
        end if
    end if
end subroutine AdjustpSenescenceToETo

subroutine CheckGermination()

    real(dp) :: Zroot, WCGermination
    logical :: SWCtopSoilConsidered_temp

    ! total root zone is considered
    Zroot = GetCrop_RootMin()
    SWCtopSoilConsidered_temp = GetSimulation_SWCtopSoilConsidered()
    call DetermineRootZoneWC(Zroot, SWCtopSoilConsidered_temp)
    call SetSimulation_SWCtopSoilConsidered(SWCtopSoilConsidered_temp)
    WCGermination = GetRootZoneWC_WP() + (GetRootZoneWC_FC() - &
                    GetRootZoneWC_WP()) * (GetSimulParam_TAWGermination()/100._dp)
    if (GetRootZoneWC_Actual() < WCGermination) then
        call SetSimulation_DelayedDays(GetSimulation_DelayedDays() + 1)
        call SetSimulation_SumGDD(0._dp)
    else
        call SetSimulation_Germinate(.true.)
        if (GetCrop_Planting() == plant_Seed) then
            call SetSimulation_ProtectedSeedling(.true.)
        else
            call SetSimulation_ProtectedSeedling(.false.)
        end if
    end if
end subroutine CheckGermination

subroutine calculate_transpiration(Tpot, Coeffb0Salt, Coeffb1Salt, Coeffb2Salt)
    real(dp), intent(in) :: Tpot
    real(dp), intent(in) :: Coeffb0Salt 
    real(dp), intent(in) :: Coeffb1Salt
    real(dp), intent(in) :: Coeffb2Salt


    real(dp) :: WtoExtract, theta_critical, alfa, sinkMM
    integer(int32) :: compi, layeri, pre_layer
    real(dp) :: DeltaWC, InetThreshold
    real(dp) :: TpotMAX, RedFact, RedFactECsw
    real(dp) :: Wrel, WrelSalt, pStomatLLAct, crop_pActStom_tmp
    real(dp) :: CompiECe, CompiECsw, CompiECswFC
    logical :: SWCtopSoilConsidered_temp
    type(CompartmentIndividual), dimension(max_No_compartments) :: Comp_temp
    type(CompartmentIndividual) :: Compi_temp


    call SetTact(0.0_dp)

    if (Tpot > 0._dp) then
        ! 1. maximum transpiration in actual root zone
        if (GetIrriMode() == IrriMode_Inet) then
            ! salinity stress not considered
            TpotMAX = Tpot
        else
            SWCtopSoilConsidered_temp = GetSimulation_SWCtopSoilConsidered()
            call DetermineRootZoneWC(GetRootingDepth(), SWCtopSoilConsidered_temp)
            call SetSimulation_SWCtopSoilConsidered(SWCtopSoilConsidered_temp)
            
            ! --- 1. Effect of water stress and ECe (total rootzone)
            WrelSalt = (GetRootZoneWC_FC()-GetRootZoneWC_Actual())/ &
                       (GetRootZoneWC_FC()-GetRootZoneWC_WP())
            
            ! --- 2. Effect of water stress
            pStomatLLAct = 1._dp
            if (GetSimulation_SWCtopSoilConsidered() .eqv. .true.) then
                ! top soil is relative wetter than total root zone
                if (GetRootZoneWC_ZtopAct() < (0.999_dp * GetRootZoneWC_ZtopThresh())) then
                    Wrel = (GetRootZoneWC_ZtopFC() - GetRootZoneWC_ZtopAct())/ &
                           (GetRootZoneWC_ZtopFC() - GetRootZoneWC_ZtopWP())
                    crop_pActStom_tmp = GetCrop_pActStom()
                    RedFact = (1._dp - GetSimulation_EffectStress_RedKsSto()/100._dp) &
                              * KsAny(Wrel, crop_pActStom_tmp, pStomatLLAct, (0.0_dp)) ! where (0.0) is linear
                    call SetCrop_pActStom(crop_pActStom_tmp)
                else
                    RedFact = (1._dp - GetSimulation_EffectStress_RedKsSto()/100._dp)
                end if
            else
                ! total root zone
                if (GetRootZoneWC_Actual() < (0.999_dp * GetRootZoneWC_Thresh())) then
                    Wrel = (GetRootZoneWC_FC()-GetRootZoneWC_Actual())/ &
                            (GetRootZoneWC_FC()-GetRootZoneWC_WP())
                    crop_pActStom_tmp = GetCrop_pActStom()
                    RedFact = (1._dp - GetSimulation_EffectStress_RedKsSto()/100._dp) &
                              * KsAny(Wrel, crop_pActStom_tmp, pStomatLLAct, (0.0_dp)) ! where (0.0) is linear
                    call SetCrop_pActStom(crop_pActStom_tmp)
                else
                    RedFact = (1._dp - GetSimulation_EffectStress_RedKsSto()/100._dp)
                end if
            end if
            
            if (RedFact < 0._dp) then
                RedFact = 0._dp
            end if
            if (RedFact > 1._dp) then
                RedFact = 1._dp
            end if
            
            ! --- 3. Extra effect of ECsw (salt in total root zone is considered)
            if (GetSimulation_SalinityConsidered()) then
                RedFactECsw = AdjustedKsStoToECsw(GetCrop_ECemin(), &
                              GetCrop_ECemax(), GetCrop_ResponseECsw(), &
                              GetRootZoneSalt_ECe(), GetRootZoneSalt_ECsw(), &
                              GetRootZoneSalt_ECswFC(), WrelSalt, Coeffb0Salt, &
                              Coeffb1Salt, Coeffb2Salt, RedFact)
            else
                RedFactECsw = RedFact
            end if
            
            ! --- 4. Conclusion (adjustment of TpotMAX considering Water and Salt stress)
            TpotMAX = RedFactECsw * Tpot
            
            ! 1.b anaerobic conditions in root zone (total root zone is considered)
            call DetermineRootZoneAnaeroConditions(GetRootZoneWC_SAT(), &
                                              GetRootZoneWC_Actual(), &
                                              real(GetCrop_AnaeroPoint(), kind=dp), &
                                              GetRootingDepth(), RedFact)
            TpotMAX = RedFact * TpotMax
        end if
        
        ! 2. extraction of TpotMax out of the compartments
        ! 2.a initial settings
        Comp_temp = GetCompartment()
        call calculate_rootfraction_compartment(GetRootingDepth(), Comp_temp)
        call calculate_sink_values(TpotMAX, GetRootingDepth(), Comp_temp, GetCrop())
        call SetCompartment(Comp_temp)
        compi = 0
        pre_layer = 0
        loop: do
            compi = compi + 1
            layeri = GetCompartment_Layer(compi)
            if (layeri > pre_layer) then
                call calculate_theta_critical(layeri, theta_critical)
                pre_layer = layeri
            end if
            ! 2.b calculate alfa
            if (GetIrriMode() == IrriMode_Inet) then
                alfa = 1._dp
            else
                ! effect of water stress and ECe
                if (GetCompartment_theta(compi) >= theta_critical) then
                    alfa = (1 - GetSimulation_EffectStress_RedKsSto()/100._dp)
                elseif (GetCompartment_theta(compi) > (GetSoilLayer_WP(layeri)/100._dp)) then
                    if (theta_critical > (GetSoilLayer_WP(layeri)/100._dp)) then
                        Wrel = (GetSoilLayer_FC(layeri)/100._dp - &
                        GetCompartment_theta(compi))/ &
                        (GetSoilLayer_FC(layeri)/100._dp - GetSoilLayer_WP(layeri)/100._dp)
                        pStomatLLAct = 1._dp
                        crop_pActStom_tmp = GetCrop_pActStom()
                        alfa = (1._dp - GetSimulation_EffectStress_RedKsSto()/100._dp) &
                               * KsAny(Wrel, crop_pActStom_tmp, pStomatLLAct, &
                                                 GetCrop_KsShapeFactorStomata())
                        call SetCrop_pActStom(crop_pActStom_tmp)
                    else
                        alfa = (1._dp - GetSimulation_EffectStress_RedKsSto()/100._dp)
                    end if
                else
                    alfa = 0._dp
                end if
                ! extra effect of ECsw
                if (GetSimulation_SalinityConsidered()) then
                    WrelSalt = (GetSoilLayer_FC(layeri)/100._dp - GetCompartment_theta(compi)) &
                    /(GetSoilLayer_FC(layeri)/100._dp - GetSoilLayer_WP(layeri)/100._dp)
                    CompiECe = ECeComp(GetCompartment_i(compi))
                    CompiECsw = ECswComp(GetCompartment_i(compi), (.false.))
                    CompiECswFC = ECswComp(GetCompartment_i(compi), (.true.))
                    RedFactECsw = AdjustedKsStoToECsw(GetCrop_ECemin(), &
                                  GetCrop_ECemax(), GetCrop_ResponseECsw(), &
                                  CompiECe, CompiECsw, CompiECswFC, WrelSalt, &
                                  Coeffb0Salt, Coeffb1Salt, Coeffb2Salt, alfa)
                else
                    RedFactECsw = alfa
                end if
                alfa = RedFactECsw
            end if
            if (GetCrop_AnaeroPoint() > 0._dp) then
                Compi_temp = GetCompartment_i(compi)
                call Correction_Anaeroby(Compi_temp, alfa)
                call SetCompartment_i(compi, Compi_temp)
            end if
            ! 2.c extract water
            sinkMM = 1000._dp * (alfa * GetCompartment_WFactor(compi) * &
                    GetCompartment_Smax(compi)) * GetCompartment_Thickness(compi)
            WtoExtract = TpotMAX-GetTact()
            if (WtoExtract < sinkMM) then
                sinkMM = WtoExtract
            end if
            call SetCompartment_theta(compi, GetCompartment_theta(compi) &
                 - sinkMM/(1000._dp*GetCompartment_Thickness(compi)* &
                 (1._dp - GetSoilLayer_GravelVol(layeri)/100._dp)))
            WtoExtract = WtoExtract - sinkMM
            call SetTact(GetTact() + sinkMM)
            if ((WtoExtract <= epsilon(1._dp) .or. (compi == GetNrCompartments()))) exit loop
        end do loop

        
        ! 3. add net irrigation water requirement
        if (GetIrriMode() == IrriMode_Inet) then
            ! total root zone is considered
            SWCtopSoilConsidered_temp = GetSimulation_SWCtopSoilConsidered()
            call DetermineRootZoneWC(GetRootingDepth(), SWCtopSoilConsidered_temp)
            call SetSimulation_SWCtopSoilConsidered(SWCtopSoilConsidered_temp)
            InetThreshold = GetRootZoneWC_FC() - GetSimulParam_PercRAW()/100._dp &
                            *(GetRootZoneWC_FC() - GetRootZoneWC_Thresh())
            if (GetRootZoneWC_Actual() < InetThreshold) then
                pre_layer = 0
                do compi = 1, GetNrCompartments()
                    layeri = GetCompartment_Layer(compi)
                    if (layeri > pre_layer) then
                        call calculate_theta_critical(layeri, theta_critical)
                        InetThreshold = GetSoilLayer_FC(layeri)/100._dp - &
                                        GetSimulParam_PercRAW()/100._dp* &
                                        (GetSoilLayer_FC(layeri)/100._dp - theta_critical)
                        pre_layer = layeri
                    end if
                    DeltaWC = GetCompartment_WFactor(compi) * &
                              (InetThreshold - GetCompartment_Theta(compi)) &
                              *1000._dp*GetCompartment_Thickness(compi)* &
                              (1._dp - GetSoilLayer_GravelVol(layeri)/100._dp)
                    call SetCompartment_Theta(compi, GetCompartment_theta(compi) &
                         + DeltaWC/(1000._dp*GetCompartment_Thickness(compi)* &
                        (1._dp - GetSoilLayer_GravelVol(layeri)/100._dp))) 
                    call SetIrrigation(GetIrrigation() + DeltaWC)
                end do
            end if
        end if
    end if

    contains

    subroutine calculate_theta_critical(layeri, theta_critical)
        integer(int32), intent(in) :: layeri
        real(dp), intent(inout) :: theta_critical


        real(dp) :: theta_TAW

        theta_TAW = GetSoilLayer_FC(layeri)/100._dp - GetSoilLayer_WP(layeri)/100._dp
        theta_critical = GetSoilLayer_FC(layeri)/100._dp - theta_TAW * GetCrop_pActStom()
    end subroutine calculate_theta_critical


    subroutine calculate_rootfraction_compartment(RootingDepth, Compartment)
        real(dp), intent(in) :: RootingDepth
        type(CompartmentIndividual), dimension(max_No_compartments), &
                                    intent(inout) :: Compartment



        real(dp) ::  frac_value, cumdepth
        integer(int32) :: compi, i

        cumdepth = 0._dp
        compi = 0
        loop: do
            compi = compi + 1
            cumdepth = cumdepth + Compartment(compi)%Thickness
            if (cumdepth <= RootingDepth) then
                Compartment(compi)%WFactor = 1
            else
                frac_value = RootingDepth - (cumdepth - Compartment(compi)%Thickness)
                if (frac_value > 0._dp) then
                    Compartment(compi)%WFactor = frac_value/Compartment(compi)%Thickness
                else
                    Compartment(compi)%WFactor = 0._dp
                end if
            end if
            if ((cumdepth >= RootingDepth) .or. (compi == GetNrCompartments())) exit loop
        end do loop
        do i = compi+1, GetNrCompartments()
            Compartment(i)%WFactor = 0._dp
        end do
    end subroutine calculate_rootfraction_compartment


    subroutine calculate_sink_values(Tpot, RootingDepth, Compartment, Crop)
        real(dp), intent(in) :: Tpot
        real(dp), intent(in) :: RootingDepth
        type(CompartmentIndividual), dimension(max_No_compartments), &
                                    intent(inout) :: Compartment
        type(rep_crop), intent(in) :: Crop


        real(dp) ::       sink_value, StopComp, SbotComp, cumdepth
        integer(int32) :: compi, i

        if (GetIrriMode() == IrriMode_Inet) then
            sink_value = (GetCrop_SmaxTop() + GetCrop_SmaxBot())/2._dp
            do compi = 1, GetNrCompartments()
                Compartment(compi)%Smax = sink_value
            end do
        else
            cumdepth = 0._dp
            compi = 0
            SbotComp = GetCrop_SmaxTop()
            loop: do
                compi = compi + 1
                StopComp = SbotComp
                cumdepth = cumdepth + Compartment(compi)%Thickness
                if (cumdepth <= RootingDepth) then
                    SbotComp = GetCrop_SmaxBot() * GetSimulation_SCor() + &
                             (GetCrop_SmaxTop()- GetCrop_SmaxBot()*GetSimulation_SCor()) &
                                                * (RootingDepth - cumdepth)/RootingDepth
                else
                    SbotComp = GetCrop_SmaxBot()*GetSimulation_SCor()
                end if
                Compartment(compi)%Smax = ((StopComp + SbotComp)/2._dp)
                if (Compartment(compi)%Smax > 0.06_dp) then
                    Compartment(compi)%Smax = 0.06_dp
                end if
                if ((cumdepth >= RootingDepth) .or. (compi == GetNrCompartments())) exit loop
            end do loop
            do i = (compi + 1), GetNrCompartments()
                Compartment(i)%Smax = 0._dp
            end do
        end if
    end subroutine calculate_sink_values


    subroutine Correction_Anaeroby(Comp, alfa)
        type(CompartmentIndividual), intent(inout) :: Comp
        real(dp), intent(inout) :: alfa


        real(dp) :: alfaAN
        integer(int32) :: ini
        if ((DaySubmerged >= GetSimulParam_DelayLowOxygen()) .and. (GetCrop_AnaeroPoint() > 0._dp)) then
            alfaAN = 0._dp
        elseif (Comp%theta > (GetSoilLayer_SAT(Comp%Layer)- GetCrop_AnaeroPoint())/100._dp) then
            Comp%DayAnaero = Comp%DayAnaero + 1
            if (Comp%DayAnaero >= GetSimulParam_DelayLowOxygen()) then
                ini = 0
                Comp%DayAnaero = GetSimulParam_DelayLowOxygen()
            else
                ini = 1
            end if
            alfaAN = (GetSoilLayer_SAT(Comp%Layer)/100._dp - Comp%theta)/(GetCrop_AnaeroPoint()/100._dp)
            if (alfaAN < 0._dp) then
                alfaAN = 0._dp
            end if
            if (GetSimulParam_DelayLowOxygen() > 1._dp) then
                alfaAN = (ini+(Comp%DayAnaero-1._dp)*alfaAN)/(ini+Comp%DayAnaero-1._dp)
            end if
        else
            alfaAN = 1._dp
            Comp%DayAnaero = 0._dp
        end if
        if (alfa > alfaAN) then
            alfa = alfaAN
        end if
    end subroutine Correction_Anaeroby


    subroutine DetermineRootZoneAnaeroConditions(Wsat, Wact, AnaeVol, Zr, RedFact)
        real(dp), intent(in) :: Wsat
        real(dp), intent(in) :: Wact
        real(dp), intent(in) :: AnaeVol
        real(dp), intent(in) :: Zr
        real(dp), intent(inout) :: RedFact


        real(dp) :: SATVol, ACTVol
        RedFact = 1
        if ((AnaeVol > 0._dp) .and. (Zr > 0._dp)) then
            SATVol = Wsat/(10._dp*Zr)
            ACTVol = Wact/(10._dp*Zr)
            if (ACTVol > SATVol) then
                ACTVol = SATVol
            end if
            if (ActVol > (SatVol-AnaeVol)) then
                call SetSimulation_DayAnaero(GetSimulation_DayAnaero() + 1_int8)
                if (GetSimulation_DayAnaero() > GetSimulParam_DelayLowOxygen()) then
                    call SetSimulation_DayAnaero(int(GetSimulParam_DelayLowOxygen(), kind=int8))
                end if
                RedFact = 1._dp - (1._dp-((SATVol - ACTVol)/AnaeVol))* (GetSimulation_DayAnaero()/GetSimulParam_DelayLowOxygen())
            else
                call SetSimulation_DayAnaero(0_int8)
            end if
        else
            call SetSimulation_DayAnaero(0_int8)
        end if
    end subroutine DetermineRootZoneAnaeroConditions

end subroutine calculate_transpiration


subroutine surface_transpiration(Coeffb0Salt, Coeffb1Salt, Coeffb2Salt)
    real(dp), intent(in) :: Coeffb0Salt 
    real(dp), intent(in) :: Coeffb1Salt
    real(dp), intent(in) :: Coeffb2Salt

    real(dp) :: Textra, Part
    integer(int32) :: compi
    real(dp) :: KsReduction, SaltSurface
    real(dp) :: Tact_temp

    DaySubmerged = DaySubmerged + 1
    do compi = 1, GetNrCompartments()
        call SetCompartment_DayAnaero(compi, GetCompartment_DayAnaero(compi) + 1)
        if (GetCompartment_DayAnaero(compi) > GetSimulParam_DelayLowOxygen()) then
            call SetCompartment_DayAnaero(compi, GetSimulParam_DelayLowOxygen())
        end if
    end do
    if (GetCrop_AnaeroPoint() > 0._dp) then
        Part = (1-DaySubmerged/GetSimulParam_DelayLowOxygen())
    else
        Part = 1
    end if
    KsReduction = KsSalinity(GetSimulation_SalinityConsidered(), GetCrop_ECemin(), &
                  GetCrop_ECemax(), GetECstorage(), (0.0_dp))
    SaltSurface = SurfaceStorage*GetECstorage()*Equiv
    if (SurfaceStorage > KsReduction*Part*GetTpot()) then
        SurfaceStorage = SurfaceStorage - KsReduction*Part*GetTpot()
        call SetTact(KsReduction*Part*GetTpot())
        call SetECstorage(SaltSurface/(SurfaceStorage*Equiv)) ! salinisation of surface storage layer
    else
        call SetTact(SurfaceStorage -0.1_dp)
        SurfaceStorage = 0.1_dp ! zero give error in already updated salt balance
    end if
    if (GetTact() < KsReduction*Part*GetTpot()) then
        Tact_temp = GetTact()   !(*Protect Tact from changes in the next routine*)
        call calculate_transpiration((KsReduction*Part*GetTpot()-GetTact()),Coeffb0Salt, Coeffb1Salt, Coeffb2Salt)
        call SetTact(Tact_temp + GetTact())
    end if
end subroutine surface_transpiration

!-----------------------------------------------------------------------------
! BUDGET_module
!-----------------------------------------------------------------------------

real(dp) function calculate_delta_theta(theta_in, thetaAdjFC, NrLayer)
    real(dp), intent(in) :: theta_in
    real(dp), intent(in) :: thetaAdjFC
    integer(int32), intent(in) :: NrLayer

    real(dp) :: DeltaX, theta, theta_sat, theta_fc

    theta = theta_in
    theta_sat = GetSoilLayer_SAT(NrLayer) / 100.0_dp
    theta_fc = GetSoilLayer_FC(NrLayer) / 100.0_dp
    if (theta > theta_sat) then
        theta = theta_sat
    end if
    if (theta <= thetaAdjFC/100.0_dp) then
        DeltaX = 0.0_dp
    else
        DeltaX = GetSoilLayer_tau(NrLayer)&
                 * (theta_sat - theta_fc)&
                 * (exp(theta - theta_fc) - 1.0_dp)&
                 / (exp(theta_sat - theta_fc) - 1.0_dp)
        if ((theta - DeltaX) < thetaAdjFC) then
            DeltaX = theta - thetaAdjFC
        end if
    end if
    calculate_delta_theta = DeltaX
end function calculate_delta_theta


real(dp) function calculate_theta(delta_theta, thetaAdjFC, NrLayer)
    real(dp), intent(in) :: delta_theta
    real(dp), intent(in) :: thetaAdjFC
    integer(int32), intent(in) :: NrLayer

    real(dp) :: ThetaX, theta_sat, theta_fc, tau

    theta_sat = GetSoilLayer_SAT(NrLayer) / 100.0_dp
    theta_fc = GetSoilLayer_FC(NrLayer) / 100.0_dp
    tau = GetSoilLayer_tau(NrLayer)
    if (delta_theta <= epsilon(0.0_dp)) then
        ThetaX = thetaAdjFC
    elseif (tau > 0.0_dp) then
        ThetaX = theta_fc&
            + log(1.0_dp&
                  + delta_theta&
                  * (exp(theta_sat - theta_fc) - 1.0_dp)&
                  / (tau * (theta_sat - theta_fc)))
        if (ThetaX < thetaAdjFC) then
            ThetaX = thetaAdjFC
        end if
    else
        ! to stop draining
        ThetaX = theta_sat + 0.1_dp
    end if
    calculate_theta = ThetaX
end function calculate_theta


subroutine calculate_drainage()
    integer(int32) ::  i, compi, layeri, pre_nr
    real(dp) :: drainsum, delta_theta, drain_comp, drainmax, theta_x, excess
    real(dp) :: pre_thick
    logical :: drainability

    drainsum = 0.0_dp
    do compi=1, GetNrCompartments()
        ! 1. Calculate drainage of compartment
        ! ====================================
        layeri = GetCompartment_Layer(compi)
        if (GetCompartment_theta(compi) &
                 > GetCompartment_FCadj(compi)/100.0_dp) then
            delta_theta = calculate_delta_theta(GetCompartment_theta(compi), &
                (GetCompartment_FCadj(compi)/100.0_dp), layeri)
        else
            delta_theta = 0.0_dp
        end if
        drain_comp = delta_theta * 1000.0_dp * GetCompartment_Thickness(compi) &
                      * (1 - GetSoilLayer_GravelVol(layeri)/100.0_dp)


        ! 2. Check drainability
        ! =====================
        excess = 0.0_dp
        pre_thick = 0.0_dp
        do i = 1, (compi-1)
            pre_thick = pre_thick + GetCompartment_Thickness(i)
        end do
        drainmax = delta_theta * 1000.0_dp * pre_thick &
                   * (1 - GetSoilLayer_GravelVol(layeri)/100.0_dp)
        if (drainsum <= drainmax) then
            drainability = .true.
        else
            drainability = .false.
        end if

        ! 3. Drain compartment
        ! ====================
        if (drainability) then
            call SetCompartment_theta(compi, &
                     GetCompartment_theta(compi)-delta_theta)
            drainsum = drainsum + drain_comp
            call CheckDrainsum(layeri, drainsum, excess)
        else  ! drainability == .false.
            delta_theta = drainsum/(1000.0_dp * pre_thick&
                                    *(1-GetSoilLayer_GravelVol(layeri)/100.0_dp))
            theta_x = calculate_theta(delta_theta, &
                (GetCompartment_FCadj(compi)/100.0_dp), layeri)

            if (theta_x <= GetSoilLayer_SAT(layeri)/100.0_dp) then
                call SetCompartment_theta(compi, &
                         GetCompartment_theta(compi) &
                         + drainsum/(1000.0_dp*GetCompartment_Thickness(compi) &
                                     *(1-GetSoilLayer_GravelVol(layeri)/100.0_dp)))
                if (GetCompartment_theta(compi) > theta_x) then
                    drainsum = (GetCompartment_theta(compi) - theta_x) &
                               * 1000.0_dp * GetCompartment_Thickness(compi) &
                               * (1 - GetSoilLayer_GravelVol(layeri)/100.0_dp)
                    delta_theta = calculate_delta_theta(theta_x, &
                        (GetCompartment_FCadj(compi)/100.0_dp), layeri)
                    drainsum = drainsum +  delta_theta * 1000.0_dp &
                                           * GetCompartment_Thickness(compi) &
                                           * (1 - GetSoilLayer_GravelVol(layeri)&
                                                  /100.0_dp)
                    call CheckDrainsum(layeri, drainsum, excess)
                    call SetCompartment_theta(compi, theta_x - delta_theta)
                elseif (GetCompartment_theta(compi) &
                         > GetCompartment_FCadj(compi)/100.0_dp) then
                    delta_theta = calculate_delta_theta(&
                        GetCompartment_theta(compi), &
                        (GetCompartment_FCadj(compi)/100.0_dp), &
                        layeri)
                    call SetCompartment_theta(compi, &
                             GetCompartment_theta(compi) - delta_theta)
                    drainsum = delta_theta * 1000.0_dp &
                               * GetCompartment_Thickness(compi) &
                               * (1 - GetSoilLayer_GravelVol(layeri)/100.0_dp)
                    call CheckDrainsum(layeri, drainsum, excess)
                else
                    drainsum = 0.0_dp
                end if
            end if ! theta_x <= SoilLayer[layeri].SAT/100

            if (theta_x > GetSoilLayer_SAT(layeri)/100.0_dp) then
                call SetCompartment_theta(compi,&
                         GetCompartment_theta(compi)&
                         + drainsum/(1000.0_dp*GetCompartment_Thickness(compi) &
                                     *(1-GetSoilLayer_GravelVol(layeri)/100.0_dp)))
                if (GetCompartment_theta(compi) &
                         <= GetSoilLayer_SAT(layeri)/100.0_dp) then
                    if (GetCompartment_theta(compi) &
                            > GetCompartment_FCadj(compi)/100.0_dp) then
                        delta_theta = calculate_delta_theta(&
                            GetCompartment_theta(compi), &
                            (GetCompartment_FCadj(compi)/100.0_dp),&
                            layeri)
                        call SetCompartment_theta(compi, &
                                 GetCompartment_theta(compi) - delta_theta)
                        drainsum = delta_theta * 1000.0_dp &
                                   * GetCompartment_Thickness(compi) &
                                   *(1-GetSoilLayer_GravelVol(layeri)/100.0_dp)
                        call CheckDrainsum(layeri, drainsum, excess)
                    else
                        drainsum = 0.0_dp
                    end if
                end if
                if (GetCompartment_theta(compi)&
                        > GetSoilLayer_SAT(layeri)/100.0_dp) then
                    excess = (GetCompartment_theta(compi)&
                               - (GetSoilLayer_SAT(layeri)/100.0_dp)) &
                             * 1000.0_dp * GetCompartment_Thickness(compi) &
                             * (1 - GetSoilLayer_GravelVol(layeri)/100.0_dp)
                    delta_theta = calculate_delta_theta(&
                         GetCompartment_theta(compi), &
                         (GetCompartment_FCadj(compi)/100),&
                         layeri)
                    call SetCompartment_theta(compi, &
                             GetSoilLayer_SAT(layeri)/100.0_dp - delta_theta)
                    drain_comp = delta_theta * 1000.0_dp&
                                 * GetCompartment_Thickness(compi)&
                                 * (1 - GetSoilLayer_GravelVol(layeri)/100.0_dp)
                    drainmax = delta_theta * 1000.0_dp * pre_thick&
                               * (1 - GetSoilLayer_GravelVol(layeri)/100.0_dp)
                    if (drainmax > excess) then
                        drainmax = excess
                    end if
                    excess = excess - drainmax
                    drainsum = drainmax + drain_comp
                    call CheckDrainsum(layeri, drainsum, excess)
                end if
            end if ! theta_x > SoilLayer[layeri].SAT/100
        end if ! drainability = false

        call SetCompartment_fluxout(compi, drainsum)


        ! 4. Redistribute excess
        ! ======================
        if (excess > 0.0_dp) then
            pre_nr = compi + 1
            loop: do
                pre_nr = pre_nr - 1
                layeri = GetCompartment_Layer(pre_nr)
                if (pre_nr < compi) then
                    call SetCompartment_fluxout(pre_nr,&
                             GetCompartment_fluxout(pre_nr) - excess)
                end if
                call SetCompartment_theta(pre_nr,&
                    GetCompartment_theta(pre_nr)&
                    + excess&
                    / (1000.0_dp*GetCompartment_Thickness(pre_nr)&
                       *(1-GetSoilLayer_GravelVol(GetCompartment_Layer(pre_nr))&
                           /100.0_dp)))
                if (GetCompartment_theta(pre_nr) &
                        > GetSoilLayer_SAT(layeri)/100.0_dp) then
                    excess = (GetCompartment_theta(pre_nr) &
                              - GetSoilLayer_SAT(layeri)/100) &
                             * 1000.0_dp * GetCompartment_Thickness(pre_nr) &
                             * (1-GetSoilLayer_GravelVol(GetCompartment_Layer(pre_nr))&
                                    /100.0_dp)
                    call SetCompartment_theta(pre_nr,&
                             GetSoilLayer_SAT(layeri)/100.0_dp)
                else
                    excess = 0.0_dp
                end if
                if ((excess == 0) .or. (pre_nr == 1)) exit loop
            end do loop
            ! redistribute excess
        end if

    !Do-loop
    end do
    call SetDrain(drainsum)

contains

    subroutine CheckDrainsum(layeri, drainsum, excess)
        integer(int32), intent(in) :: layeri
        real(dp), intent(inout) :: drainsum
        real(dp), intent(inout) :: excess

        if (drainsum > GetSoilLayer_InfRate(layeri)) then
            excess = excess + drainsum - GetSoilLayer_InfRate(layeri)
            drainsum = GetSoilLayer_InfRate(layeri)
        end if
    end subroutine CheckDrainsum

end subroutine calculate_drainage


subroutine calculate_weighting_factors(Depth, Compartment)
    real(dp), intent(in) :: Depth
    type(CompartmentIndividual), dimension(max_No_compartments), intent(inout) :: Compartment

    integer(int32) :: i, compi
    real(dp) :: CumDepth, xx, wx

    CumDepth = 0.0_dp
    xx = 0.0_dp
    compi = 0
    loop: do
        compi = compi + 1
        CumDepth = CumDepth + Compartment(compi)%Thickness
        if (CumDepth > Depth) then
            CumDepth = Depth
        end if
        wx = 1.016_dp * (1.0_dp - EXP(-4.16_dp * CumDepth/Depth))
        Compartment(compi)%WFactor = wx - xx
        if (Compartment(compi)%WFactor > 1.0_dp) then
            Compartment(compi)%WFactor = 1.0_dp
        end if
        if (Compartment(compi)%WFactor < 0.0_dp) then
            Compartment(compi)%WFactor = 0.0_dp
        end if
        xx = wx
        if ((CumDepth >= Depth) .or. (compi == GetNrCompartments())) exit loop
    enddo loop
    do i = (compi + 1), GetNrCompartments()
        Compartment(i)%WFactor = 0.0_dp
    end do
end subroutine calculate_weighting_factors


subroutine calculate_runoff(MaxDepth)
    real(dp), intent(in) :: MaxDepth

    real(dp) :: SUM, CNA, Shower, term, S
    integer(int8) :: CN2, CN1, CN3

    CN2 = roundc(GetSoil_CNvalue()&
                 * (100 + GetManagement_CNcorrection())/100.0_dp,&
                 mold=1_int8)
    if (GetRainRecord_DataType() == datatype_daily) then
        if (GetSimulParam_CNcorrection()) then
            call calculate_relative_wetness_topsoil(SUM)
            call DetermineCNIandIII(CN2, CN1, CN3)
            CNA = real(roundc(CN1+(CN3-CN1)*SUM, mold=1_int32), kind=dp)
        else
            CNA = real(CN2, kind=dp)
        end if
        Shower = GetRain()
    else
        CNA = real(CN2, kind=dp)
        Shower = (GetRain()*10.0_dp)&
                 / GetSimulParam_EffectiveRain_ShowersInDecade()
    end if
    S = 254.0_dp * (100.0_dp/CNA - 1.0_dp)
    term = Shower - (GetSimulParam_IniAbstract()/100.0_dp) * S
    if (term <= epsilon(0.0_dp)) then
        call SetRunoff(0.0_dp);
    else
        call SetRunoff(term**2&
             / (Shower + (1.0_dp - (GetSimulParam_IniAbstract()/100.0_dp)) * S))
    end if
    if ((GetRunoff() > 0.0_dp) .and. ( &
            (GetRainRecord_DataType() == datatype_decadely)&
             .or. (GetRainRecord_DataType() == datatype_monthly))) then
        if (GetRunoff() >= Shower) then
            call SetRunoff(GetRain())
        else
            call SetRunoff(GetRunoff() &
                   * (GetSimulParam_EffectiveRain_ShowersInDecade()/10.14_dp))
            if (GetRunoff() > GetRain()) then
                call SetRunoff(GetRain())
            end if
        end if
    end if

    contains

    subroutine calculate_relative_wetness_topsoil(SUM)
        real(dp), intent(inout) :: SUM

        real(dp) :: CumDepth, theta
        integer(int32) :: compi, layeri
        type(CompartmentIndividual), dimension(max_No_compartments) :: Compartment_temp

        Compartment_temp = GetCompartment()
        call calculate_weighting_factors(MaxDepth, Compartment_temp)
        call SetCompartment(Compartment_temp)
        SUM = 0.0_dp
        compi = 0
        CumDepth = 0.0_dp

        loop : do
            compi = compi + 1
            layeri = GetCompartment_Layer(compi)
            CumDepth = CumDepth + GetCompartment_Thickness(compi)
            if (GetCompartment_theta(compi) < GetSoilLayer_WP(layeri)/100.0_dp) then
                theta = GetSoilLayer_WP(layeri)/100.0_dp
            else
                theta = GetCompartment_theta(compi)
            end if
            SUM = SUM + GetCompartment_WFactor(compi) &
                 * (theta-GetSoilLayer_WP(layeri)/100.0_dp) &
                 / (GetSoilLayer_FC(layeri)/100.0_dp - GetSoilLayer_WP(layeri)/100.0_dp)
            if ((CumDepth >= MaxDepth) .or. (compi == GetNrCompartments())) exit loop
        end do loop

        if (SUM < 0.0_dp) then
            SUM = 0.0_dp
        end if
        if (SUM > 1.0_dp) then
            SUM = 1.0_dp
        end if

    end subroutine calculate_relative_wetness_topsoil

end subroutine calculate_runoff


subroutine Calculate_irrigation(SubDrain, TargetTimeVal, TargetDepthVal)
    real(dp), intent(inout) :: SubDrain
    integer(int32), intent(inout) :: TargetTimeVal
    integer(int32), intent(in) :: TargetDepthVal

    real(dp) :: ZrWC, RAWi
    logical :: SWCtopSoilConsidered_temp

    ! total root zone is considered
    SWCtopSoilConsidered_temp = GetSimulation_SWCtopSoilConsidered()
    call DetermineRootZoneWC(GetRootingDepth(), SWCtopSoilConsidered_temp)
    call SetSimulation_SWCtopSoilConsidered(SWCtopSoilConsidered_temp)
    ZrWC = GetRootZoneWC_Actual() - GetEpot() - GetTpot() &
           + GetRain() - GetRunoff() - SubDrain
    if (GetGenerateTimeMode() == GenerateTimeMode_AllDepl) then
        if ((GetRootZoneWC_FC() - ZrWC) >= TargetTimeVal) then
            TargetTimeVal = 1
        else
            TargetTimeVal = 0
        end if
    end if
    if (GetGenerateTimeMode() == GenerateTimeMode_AllRAW) then
        RAWi = TargetTimeVal/100._dp &
                * (GetRootZoneWC_FC() - GetRootZoneWC_Thresh())
        if ((GetRootZoneWC_FC() - ZrWC) >= RAWi) then
            TargetTimeVal = 1
        else
            TargetTimeVal = 0
        end if
    end if
    if (TargetTimeVal == 1) then
        if (GetGenerateDepthMode() == GenerateDepthMode_FixDepth) then
            call SetIrrigation(real(TargetDepthVal, kind=dp))
        else
            call SetIrrigation((GetRootZoneWC_FC() - ZrWc) &
                                            + TargetDepthVal)
            if (GetIrrigation() < 0._dp) then
                call SetIrrigation(0._dp)
            end if
        end if
    else
        call SetIrrigation(0._dp)
    end if
end subroutine Calculate_irrigation



subroutine CalculateEffectiveRainfall(SubDrain)
    real(dp), intent(inout) :: SubDrain

    real(dp) :: EffecRain, ETcropMonth, RainMonth, &
                DrainMax, Zr, depthi, DTheta, RestTheta
    integer(int32) :: compi

    if (GetRain() > 0._dp) then
        ! 1. Effective Rainfall
        EffecRain = (GetRain()-GetRunoff())
        select case (GetSimulParam_EffectiveRain_Method())
        case (EffectiveRainMethod_Percentage)
            EffecRain = (GetSimulParam_EffectiveRain_PercentEffRain()/100._dp) &
                                * (GetRain()-GetRunoff())
        case (EffectiveRainMethod_USDA)
            ETcropMonth = ((GetEpot()+GetTpot())*30._dp)/25.4_dp ! inch/month
            RainMonth = ((GetRain()-GetRunoff())*30._dp)/25.4_dp ! inch/Month
            if (RainMonth > 0.1_dp) then
                EffecRain = (0.70917_dp*exp(0.82416_dp*log(RainMonth))-0.11556_dp) &
                                * (exp(0.02426_dp*ETcropMonth*log(10._dp))) 
                                                                 ! inch/month
            else
                EffecRain = RainMonth
            end if
            EffecRain = EffecRain*(25.4_dp/30._dp) ! mm/day
        end select
    end if
    if (EffecRain < 0._dp) then
        EffecRain = 0._dp
    end if
    if (EffecRain > (GetRain()-GetRunoff())) then
        EffecRain = (GetRain()-GetRunoff())
    end if
    SubDrain = (GetRain()-GetRunoff()) - EffecRain

    ! 2. Verify Possibility of SubDrain
    if (SubDrain > 0._dp) then
        DrainMax = GetSoilLayer_InfRate(1)
        if (GetSurfaceStorage() > 0._dp) then
            DrainMax = 0._dp
        else
            Zr = GetRootingDepth()
            if (Zr <= epsilon(0._dp)) then
                Zr = (GetSimulParam_EvapZmax()/100._dp)
            end if
            compi = 0
            depthi = 0._dp
            DTheta = (EffecRain/Zr)/1000._dp
            loop: do
                compi = compi + 1
                depthi = depthi + GetCompartment_Thickness(compi)
                RestTheta = GetSoilLayer_SAT(GetCompartment_Layer(compi)) &
                            /100._dp - (GetCompartment_theta(compi) + DTheta)
                if (RestTheta <= epsilon(0._dp)) then
                    DrainMax = 0._dp
                end if
                if (GetSoilLayer_InfRate(GetCompartment_Layer(compi)) &
                                                        < DrainMax) then
                    DrainMax = GetSoilLayer_InfRate(GetCompartment_Layer(compi))
                end if
                if ((depthi >= Zr) &
                    .or. (compi >= GetNrCompartments())) exit loop
            end do loop
        end if
        if (SubDrain > DrainMax) then
            if (GetManagement_Bundheight() < 0.001_dp) then
                call SetRunoff(GetRunoff() + (SubDrain-DrainMax))
            end if
            SubDrain = DrainMax
        end if
    end if
end subroutine CalculateEffectiveRainfall



subroutine calculate_CapillaryRise(CRwater, CRsalt)
    real(dp), intent(inout) :: CRwater
    real(dp), intent(inout) :: CRsalt

    real(dp) :: Zbottom, MaxMM, DThetaMax, DTheta, LimitMM, &
                CRcomp, SaltCRi, DrivingForce, ZtopNextLayer, &
                Krel, ThetaThreshold
    integer(int32) :: compi, SCellAct, layeri

    Zbottom = 0._dp
    do compi = 1, GetNrCompartments() 
        Zbottom = Zbottom + GetCompartment_Thickness(compi)
    end do

    ! start at the bottom of the soil profile
    compi = GetNrCompartments()
    MaxMM = MaxCRatDepth(GetSoilLayer_CRa(GetCompartment_Layer(compi)), &
                         GetSoilLayer_CRb(GetCompartment_Layer(compi)), &
                         GetSoilLayer_InfRate(GetCompartment_Layer(compi)), &
                         (Zbottom - GetCompartment_Thickness(compi)/2._dp), &
                         (GetZiAqua()/100._dp))

    ! check restrictions on CR from soil layers below
    ZtopNextLayer = 0._dp
    do layeri = 1, GetCompartment_Layer(GetNrCompartments()) 
        ZtopNextLayer = ZtopNextLayer + GetSoilLayer_Thickness(layeri)
    end do
    layeri = GetCompartment_Layer(GetNrCompartments())
    do while ((ZtopNextLayer < (GetZiAqua()/100._dp)) &
                .and. (layeri < GetSoil_NrSoilLayers())) 
        layeri = layeri + 1
        LimitMM = MaxCRatDepth(GetSoilLayer_CRa(layeri), &
                               GetSoilLayer_CRb(layeri), &
                               GetSoilLayer_InfRate(layeri), &
                               ZtopNextLayer, (GetZiAqua()/100._dp))
        if (MaxMM > LimitMM) then
            MaxMM = LimitMM
        end if
        ZtopNextLayer = ZtopNextLayer + GetSoilLayer_Thickness(layeri)
    end do

    loop: do while ((roundc(MaxMM*1000._dp, mold=1) > 0) &
            .and. (compi > 0) &
            .and. (roundc(GetCompartment_fluxout(compi)*1000._dp, mold=1) == 0)) 
        ! Driving force
        if ((GetCompartment_theta(compi) &
                >= GetSoilLayer_WP(GetCompartment_Layer(compi))/100._dp) &
            .and. (GetSimulParam_RootNrDF() > 0_int8)) then
            DrivingForce = 1._dp &
                          - (exp(GetSimulParam_RootNrDF() &
                            * log(GetCompartment_theta(compi) &
                                - GetSoilLayer_WP(GetCompartment_Layer(compi)) &
                                                                    /100._dp)) &
                          /exp(GetSimulParam_RootNrDF() &
                            *log(GetCompartment_FCadj(compi)/100._dp &
                      - GetSoilLayer_WP(GetCompartment_Layer(compi))/100._dp)))
        else
            DrivingForce = 1._dp
        end if
        ! relative hydraulic conductivity
        ThetaThreshold = (GetSoilLayer_WP(GetCompartment_Layer(compi))/100._dp &
                          + GetSoilLayer_FC(GetCompartment_Layer(compi)) &
                                                                /100._dp)/2._dp
        if (GetCompartment_Theta(compi) < ThetaThreshold) then
            if ((GetCompartment_Theta(compi) &
                <= GetSoilLayer_WP(GetCompartment_Layer(compi))/100._dp) &
              .or. (ThetaThreshold &
                <= GetSoilLayer_WP(GetCompartment_Layer(compi))/100._dp)) then
                Krel = 0._dp
            else
                Krel = (GetCompartment_Theta(compi) &
                        - GetSoilLayer_WP(GetCompartment_Layer(compi))/100._dp) &
                      /(ThetaThreshold &
                        - GetSoilLayer_WP(GetCompartment_Layer(compi))/100._dp)
            end if
        else
            Krel = 1._dp
        end if
        
        ! room available to store water
        DTheta = GetCompartment_FCadj(compi)/100._dp &
                - GetCompartment_Theta(compi)
        if ((DTheta > 0._dp) &
            .and. ((Zbottom - GetCompartment_Thickness(compi)/2._dp) &
                    < (GetZiAqua()/100._dp))) then
            ! water stored
            DThetaMax = Krel * DrivingForce &
                        * MaxMM/(1000._dp*GetCompartment_Thickness(compi))
            if (DTheta >= DThetaMax) then
                call SetCompartment_Theta(compi, &
                                          GetCompartment_Theta(compi) &
                                                         + DThetaMax)
                CRcomp = DThetaMax*1000._dp*GetCompartment_Thickness(compi) &
                         * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
                MaxMM = 0._dp
            else
                call SetCompartment_Theta(compi, &
                                         GetCompartment_FCadj(compi)/100._dp)
                CRcomp = DTheta*1000._dp*GetCompartment_Thickness(compi) &
                         * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
                MaxMM = Krel * MaxMM - CRcomp
            end if
            CRwater = CRwater + CRcomp
            ! salt stored
            SCellAct = ActiveCells(GetCompartment_i(compi))
            SaltCRi = Equiv * CRcomp * GetECiAqua() ! gram/m2
            call SetCompartment_Salt(compi, SCellAct, &
                                     GetCompartment_Salt(compi, SCellAct) &
                                                               + SaltCRi)
            CRsalt = CRsalt + SaltCRi
        end if
        Zbottom = Zbottom - GetCompartment_Thickness(compi)
        compi = compi - 1
        if (compi < 1) exit loop
        LimitMM = MaxCRatDepth(&
                    GetSoilLayer_CRa(GetCompartment_Layer(compi)), &
                    GetSoilLayer_CRb(GetCompartment_Layer(compi)), &
                    GetSoilLayer_InfRate(GetCompartment_Layer(compi)), &
                    (Zbottom - GetCompartment_Thickness(compi)/2._dp), &
                    (GetZiAqua()/100._dp))
        if (MaxMM > LimitMM) then
            MaxMM = LimitMM
        end if
    end do loop
end subroutine calculate_CapillaryRise


subroutine CheckWaterSaltBalance(dayi,&
              InfiltratedRain,  &
              control, InfiltratedIrrigation,&
              InfiltratedStorage, Surf0, ECInfilt, ECdrain, &
              HorizontalWaterFlow, HorizontalSaltFlow, SubDrain)
    integer(int32), intent(in) :: dayi
    real(dp), intent(in) :: InfiltratedRain
    integer(intEnum), intent(in) :: control
    real(dp), intent(in) :: InfiltratedIrrigation
    real(dp), intent(in) :: InfiltratedStorage
    real(dp), intent(inout) :: Surf0
    real(dp), intent(inout) :: ECInfilt
    real(dp), intent(inout) :: ECdrain
    real(dp), intent(inout) :: HorizontalWaterFlow
    real(dp), intent(inout) :: HorizontalSaltFlow
    real(dp), intent(inout) :: SubDrain

    integer(int32) :: compi, layeri, celli
    real(dp) :: Surf1, ECw

    select case (control)
    case (control_begin_day)
        call SetTotalWaterContent_BeginDay(0._dp) ! mm
        Surf0 = GetSurfaceStorage() ! mm
        call SetTotalSaltContent_BeginDay(0._dp) ! Mg/ha
        do compi =1, GetNrCompartments()
            call SetTotalWaterContent_BeginDay(GetTotalWaterContent_BeginDay() &
               + GetCompartment_theta(compi)*1000._dp* &
                 GetCompartment_Thickness(compi) &
               * (1._dp - &
                  GetSoilLayer_GravelVol(GetCompartment_Layer(compi))/100._dp))
            call SetCompartment_fluxout(compi, 0._dp)
            do celli = 1, GetSoilLayer_SCP1(GetCompartment_Layer(compi))
                call SetTotalSaltContent_BeginDay(&
                       GetTotalSaltContent_BeginDay() &
                       + (GetCompartment_Salt(compi, celli) + &
                          GetCompartment_Depo(compi, celli))/100._dp) ! Mg/ha
            end do
        end do
        call SetDrain(0._dp)
        call SetRunoff(0._dp)
        ! Eact is set to 0 at the beginning of the evaporation process
        call SetTact(0._dp)
        call SetInfiltrated(0._dp)
        ECinfilt = 0._dp
        SubDrain = 0._dp
        ECdrain = 0._dp
        HorizontalWaterFlow = 0._dp
        HorizontalSaltFlow = 0._dp
        call SetCRwater(0._dp)
        call SetCRsalt(0._dp)

    case (control_end_day)
        call SetInfiltrated(InfiltratedRain+InfiltratedIrrigation &
                            +InfiltratedStorage)
        do layeri = 1, GetSoil_NrSoilLayers()
            call SetSoilLayer_WaterContent(layeri, 0._dp)
        end do
        call SetTotalWaterContent_EndDay(0._dp)
        Surf1 = GetSurfaceStorage()
        call SetTotalSaltContent_EndDay(0._dp)

        ! quality of irrigation water
        if (dayi < GetCrop_Day1()) then
            ECw = GetIrriECw_PreSeason()
        else
            ECw = GetSimulation_IrriECw()
            if (dayi > GetCrop_DayN()) then
                ECw = GetIrriECw_PostSeason()
            end if
        end if

        do compi = 1, GetNrCompartments()
            call SetTotalWaterContent_EndDay(GetTotalWaterContent_EndDay() &
               + GetCompartment_theta(compi)*1000._dp*&
                 GetCompartment_Thickness(compi) &
               * (1._dp -&
                  GetSoilLayer_GravelVol(GetCompartment_Layer(compi))/100._dp))
            call SetSoilLayer_WaterContent(GetCompartment_Layer(compi), &
                    GetSoilLayer_WaterContent(GetCompartment_Layer(compi)) &
                    + GetCompartment_theta(compi)*1000._dp*&
                          GetCompartment_theta(compi) &
                    * (1._dp - &
                       GetSoilLayer_GravelVol(GetCompartment_Layer(compi))/100._dp))
            do celli = 1, GetSoilLayer_SCP1(GetCompartment_Layer(compi))
                call SetTotalSaltContent_EndDay(GetTotalSaltContent_EndDay() &
                   + (GetCompartment_Salt(compi, celli) + &
                      GetCompartment_Depo(compi, celli))/100._dp) ! Mg/ha
            end do
        end do
        call SetTotalWaterContent_ErrorDay(GetTotalWaterContent_BeginDay() &
                + Surf0 &
                - (GetTotalWaterContent_EndDay()+GetDrain()+GetRunoff()+GetEact()&
                + GetTact()+Surf1-GetRain()-GetIrrigation()-GetCRwater()-HorizontalWaterFlow))
        call SetTotalSaltContent_ErrorDay(GetTotalSaltContent_BeginDay() &
                - GetTotalSaltContent_EndDay() & ! Mg/ha
                + InfiltratedIrrigation*ECw*Equiv/100._dp &
                + InfiltratedStorage*ECinfilt*Equiv/100._dp &
                - GetDrain()*ECdrain*Equiv/100._dp &
                + GetCRsalt()/100._dp &
                + HorizontalSaltFlow)
        call SetSumWaBal_Epot(GetSumWaBal_Epot() + GetEpot())
        call SetSumWaBal_Tpot(GetSumWaBal_Tpot() + GetTpot())
        call SetSumWaBal_Rain(GetSumWaBal_Rain() + GetRain())
        call SetSumWaBal_Irrigation(GetSumWaBal_Irrigation() + GetIrrigation())
        call SetSumWaBal_Infiltrated(GetSumWaBal_Infiltrated() + &
                  GetInfiltrated())
        call SetSumWaBal_Runoff(GetSumWaBal_Runoff() + GetRunoff())
        call SetSumWaBal_Drain(GetSumWaBal_Drain() + GetDrain())
        call SetSumWaBal_Eact(GetSumWaBal_Eact() + GetEact())
        call SetSumWaBal_Tact(GetSumWaBal_Tact() + GetTact())
        call SetSumWaBal_TrW(GetSumWaBal_TrW() + GetTactWeedInfested())
        call SetSumWaBal_CRwater(GetSumWaBal_CRwater() + GetCRwater())

        if (((dayi-GetSimulation_DelayedDays()) >= GetCrop_Day1() ) &
            .and. ((dayi-GetSimulation_DelayedDays()) <= GetCrop_DayN())) then
            ! in growing cycle
            if (GetSumWaBal_Biomass() > 0._dp) then 
                ! biomass was already produced (i.e. CC present)
                ! and still canopy cover
                if (GetCCiActual() > 0._dp) then
                    call SetSumWaBal_ECropCycle(GetSumWaBal_ECropCycle() &
                           + GetEact())
                end if
            else
                call SetSumWaBal_ECropCycle(GetSumWaBal_ECropCycle() &
                           + GetEact()) ! before germination
            end if
        end if
        call SetSumWaBal_CRsalt(GetSumWaBal_CRsalt() + GetCRsalt()/100._dp)
        call SetSumWaBal_SaltIn(GetSumWaBal_SaltIn() + &
               (InfiltratedIrrigation*ECw+InfiltratedStorage*ECinfilt)*Equiv/100._dp)
        call SetSumWaBal_SaltOut(GetSumWaBal_SaltOut() + &
                GetDrain()*ECdrain*Equiv/100._dp)
    end select
end subroutine CheckWaterSaltBalance


subroutine calculate_saltcontent(InfiltratedRain, InfiltratedIrrigation, &
                                 InfiltratedStorage, dayi, SubDrain)
    real(dp), intent(in) :: InfiltratedRain
    real(dp), intent(in) :: InfiltratedIrrigation
    real(dp), intent(in) :: InfiltratedStorage
    integer(int32), intent(in) :: dayi
    real(dp), intent(in) :: SubDrain

    real(dp) ::   SaltIN, SaltOUT, mmIN, DeltaTheta, Theta, SAT, &
                  mm1, mm2, Dx, limit, Dif, UL
    real(dp) :: Zr, depthi, ECsubdrain, ECcel, DeltaZ, ECsw1, ECsw2, &
                ECsw, SM1, SM2, DS1, DS2, DS

    integer(int32) :: compi, celi, celiM1, Ni
    real(dp) :: ECw
    real(dp) :: Salt_temp, Salt2_temp, Depo_temp, Depo2_temp
    type(CompartmentIndividual) :: Compi_temp


    mmIN = InfiltratedRain + InfiltratedIrrigation + InfiltratedStorage

    ! quality of irrigation water
    if (dayi < GetCrop_Day1()) then
        ECw = GetIrriECw_PreSeason()
    else
        ECw = GetSimulation_IrriECw()
        if (dayi > GetCrop_DayN()) then
            ECw = GetIrriECw_PostSeason()
        end if
    end if

    ! initialise salt balance
    SaltIN = InfiltratedIrrigation*ECw*Equiv &
            + InfiltratedStorage*GetECstorage()*Equiv
    call SetSaltInfiltr(SaltIN/100._dp) 
                ! salt infiltrated in soil profile kg/ha 
    SaltOut= 0._dp


    do compi = 1, GetNrCompartments() 
        ! 0. Set compartment parameters
        SAT = (GetSoilLayer_SAT(GetCompartment_Layer(compi)))/100._dp  ! m3/m3 
        UL = GetSoilLayer_UL(GetCompartment_Layer(compi)) ! m3/m3   
                                      ! Upper limit of SC salt cel 
        Dx = GetSoilLayer_Dx(GetCompartment_Layer(compi)) ! m3/m3  
                            ! Size of salts cel (expect last one) 
        
        ! 1. Initial situation before drain and infiltration
        DeltaTheta = mmIN &
           /(1000._dp*GetCompartment_Thickness(compi) &
               *(1._dp - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                  /100._dp))
        Theta = GetCompartment_theta(compi) - DeltaTheta &
                + GetCompartment_fluxout(compi) &
                        /(1000._dp*GetCompartment_Thickness(compi))
        
        ! 2. Determine active SaltCels and Add IN
        Theta = Theta + DeltaTheta
        if (Theta <= UL) then
            celi = 0
            do while (Theta > Dx*celi) 
                celi = celi + 1
            end do
        else
            celi = GetSoilLayer_SCP1(GetCompartment_Layer(compi))
        end if
        if (celi == 0) then
            celi = 1  ! XXX would be best to avoid celi=0 to begin with
        end if
        if (DeltaTheta > 0._dp) then
            call SetCompartment_Salt(compi, celi, &
                                     GetCompartment_Salt(compi, celi) &
                                        + SaltIN)
        end if
        
        ! 3. Mixing
        if (celi > 1) then
            do Ni = 1, (celi-1) 
                mm1 = Dx*1000._dp*GetCompartment_Thickness(compi) &
                        * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
                if (Ni < GetSoilLayer_SC(GetCompartment_Layer(compi))) then
                    mm2 = mm1
                elseif (Theta > SAT) then
                    mm2 = (Theta-UL)*1000._dp*GetCompartment_Thickness(compi) &
                            * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
                else
                    mm2 = (SAT-UL)*1000._dp*GetCompartment_Thickness(compi) &
                            * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
                end if
                Dif = GetSoilLayer_SaltMobility_i(GetCompartment_Layer(compi), &
                                                    Ni)
                Salt_temp = GetCompartment_Salt(compi, Ni)
                Salt2_temp = GetCompartment_Salt(compi, Ni+1)
                Depo_temp = GetCompartment_Depo(compi, Ni)
                Depo2_temp = GetCompartment_Depo(compi, Ni+1)
                call Mixing(Dif, mm1, mm2, Salt_temp, Salt2_temp, &
                                           Depo_temp, Depo2_temp)
                call SetCompartment_Salt(compi, Ni, Salt_temp)
                call SetCompartment_Salt(compi, Ni+1, Salt2_temp)
                call SetCompartment_Depo(compi, Ni, Depo_temp)
                call SetCompartment_Depo(compi, Ni+1, Depo2_temp)
            end do
        end if
        
        ! 4. Drain
        SaltOut = 0._dp
        if (GetCompartment_fluxout(compi) > 0._dp) then
            DeltaTheta = GetCompartment_fluxout(compi) &
                         /(1000._dp*GetCompartment_Thickness(compi) &
                            * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                     /100._dp))
            do while (DeltaTheta > 0._dp) 
                if (celi < GetSoilLayer_SCP1(GetCompartment_Layer(compi))) then
                    limit = (celi-1._dp)*Dx
                else
                    limit = UL
                end if
                if ((Theta - DeltaTheta) < limit) then
                    SaltOut = SaltOut + GetCompartment_Salt(compi, celi) &
                              + GetCompartment_Depo(compi, celi)
                    call SetCompartment_Salt(compi, celi, 0._dp)
                    mm1 = (Theta - limit)*1000._dp &
                           * GetCompartment_Thickness(compi) * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
                    if (SaltOut > (GetSimulParam_SaltSolub() * mm1)) then
                        call SetCompartment_Depo(compi, celi, &
                                   SaltOut - (GetSimulParam_SaltSolub() * mm1))
                        SaltOut = (GetSimulParam_SaltSolub() * mm1)
                    else
                        call SetCompartment_Depo(compi, celi, 0._dp)
                    end if
                    DeltaTheta = DeltaTheta - (Theta-limit)
                    Theta = limit
                    celi = celi - 1
                else
                    SaltOut = SaltOut &
                              + (GetCompartment_Salt(compi, celi) &
                                + GetCompartment_Depo(compi, celi)) &
                              * (DeltaTheta/(Theta-limit))
                    call SetCompartment_Salt(compi, celi, &
                                             GetCompartment_Salt(compi, celi) &
                                             * (1._dp-DeltaTheta/(Theta-limit)))
                    call SetCompartment_Depo(compi, celi, &
                                             GetCompartment_Depo(compi, celi) &
                                             * (1._dp-DeltaTheta/(Theta-limit)))
                    mm1 = DeltaTheta*1000._dp*GetCompartment_Thickness(compi) &
                            * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
                    if (SaltOut > (GetSimulParam_SaltSolub() * mm1)) then
                        call SetCompartment_Depo(&
                                compi, celi, &
                                GetCompartment_Depo(compi, celi) &
                                    + (SaltOut - GetSimulParam_SaltSolub() &
                                                                    * mm1))
                        SaltOut = (GetSimulParam_SaltSolub() * mm1)
                    end if
                    DeltaTheta = 0._dp
                    mm1 = GetSoilLayer_Dx(GetCompartment_Layer(compi)) &
                            *1000._dp*GetCompartment_Thickness(compi) &
                            * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
                    if (celi == GetSoilLayer_SCP1(GetCompartment_Layer(compi))) then
                        mm1 = 2._dp*mm1
                    end if
                    Salt_temp = GetCompartment_Salt(compi, celi)
                    Depo_temp = GetCompartment_Depo(compi, celi)
                    call SaltSolutionDeposit(mm1, Salt_temp, Depo_temp)
                    call SetCompartment_Salt(compi, celi, Salt_temp)
                    call SetCompartment_Depo(compi, celi, Depo_temp)
                end if
            end do
        end if
        
        mmIN = GetCompartment_fluxout(compi)
        SaltIN = SaltOUT
    end do

    if (GetDrain() > 0.001_dp) then
        call SetECdrain(SaltOUT/(GetDrain()*Equiv))
    end if


    ! 5. vertical salt diffusion
    celi = ActiveCells(GetCompartment_i(1))
    SM2 = GetSoilLayer_SaltMobility_i(GetCompartment_Layer(1), celi)/4._dp
    ECsw2 = ECswComp(GetCompartment_i(1), .false.) ! not at FC
    mm2 = GetCompartment_Theta(1)*1000._dp*GetCompartment_Thickness(1) &
            * (1._dp - GetSoilLayer_GravelVol(GetCompartment_Layer(1))/100._dp)
    do compi = 2, GetNrCompartments() 
        celiM1 = celi
        SM1 = SM2
        ECsw1 = ECsw2
        mm1 = mm2
        celi =  ActiveCells(GetCompartment_i(compi))
        SM2 = GetSoilLayer_SaltMobility_i(GetCompartment_Layer(compi), &
                                          celi)/4._dp
        ECsw2 = ECswComp(GetCompartment_i(compi), .false.) ! not at FC
        mm2 = GetCompartment_Theta(compi)*1000._dp &
                * GetCompartment_Thickness(compi) &
                * (1._dp &
                    - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                /100._dp)
        ECsw = (ECsw1*mm1+ECsw2*mm2)/(mm1+mm2)
        DS1 = (ECsw1 - (ECsw1+(ECsw-ECsw1)*SM1))*mm1*Equiv
        DS2 = (ECsw2 - (ECsw2+(ECsw-ECsw2)*SM2))*mm2*Equiv
        if (abs(DS2) < abs(DS1)) then
            DS = abs(DS2)
        else
            DS = abs(DS1)
        end if
        if (DS > 0._dp) then
            if (ECsw1 > ECsw) then
                DS = DS*(-1._dp)
            end if
            Compi_temp = GetCompartment_i(compi-1)
            call MoveSaltTo(Compi_temp, celiM1, DS)
            call SetCompartment_i(compi-1, Compi_temp)
            DS = DS*(-1._dp)
            Compi_temp = GetCompartment_i(compi)
            call MoveSaltTo(Compi_temp, celi, DS)
            call SetCompartment_i(compi, Compi_temp)
        end if
    end do




    ! 6. Internal salt movement as a result of SubDrain
    ! SubDrain part of non-effective rainfall (10-day & monthly input)
    if (SubDrain > 0._dp) then
        Zr = GetRootingDepth()
        if (Zr >= epsilon(0._dp)) then
            Zr = (GetSimulParam_EvapZmax()/100._dp) ! in meter
        end if
        compi = 0
        depthi = 0._dp
        ECsubdrain = 0._dp
        
        ! extract
        loop: do
            compi = compi + 1
            depthi = depthi + GetCompartment_Thickness(compi)
            if (depthi <= Zr) then
                DeltaZ = GetCompartment_Thickness(compi)
            else
                DeltaZ = GetCompartment_Thickness(compi) - (depthi-Zr)
            end if
            celi = ActiveCells(GetCompartment_i(compi))
            if (celi < GetSoilLayer_SCP1(GetCompartment_Layer(compi))) then
                mm1 = GetSoilLayer_Dx(GetCompartment_Layer(compi))*1000._dp &
                        * GetCompartment_Thickness(compi) &
                        * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
            else
                mm1 = 2._dp*GetSoilLayer_Dx(GetCompartment_Layer(compi)) &
                        *1000._dp*GetCompartment_Thickness(compi) &
                        * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
            end if
            ECcel = GetCompartment_Salt(compi, celi)/(mm1*Equiv)
            ECsubdrain = (ECcel*mm1*(DeltaZ/GetCompartment_Thickness(compi)) &
                                                       +ECsubdrain*SubDrain) &
                         /(mm1*(DeltaZ/GetCompartment_Thickness(compi)) &
                                                              +SubDrain)
            call SetCompartment_Salt(&
                    compi, celi, &
                    (1._dp - (DeltaZ/GetCompartment_Thickness(compi))) &
                        * GetCompartment_Salt(compi, celi) &
                    + (DeltaZ/GetCompartment_Thickness(compi)) &
                        *ECsubdrain*mm1*Equiv)
            Salt_temp = GetCompartment_Salt(compi, celi)
            Depo_temp = GetCompartment_Depo(compi, celi)
            call SaltSolutionDeposit(mm1, Salt_temp, Depo_temp)
            call SetCompartment_Salt(compi, celi, Salt_temp)
            call SetCompartment_Depo(compi, celi, Depo_temp)
            if ((depthi >= Zr) .or. (compi >= GetNrCompartments())) exit loop
        end do loop
        
        ! dump
        if (compi >= GetNrCompartments()) then
            SaltOUT = GetECdrain()*(GetDrain()*Equiv) + ECsubdrain*SubDrain*Equiv
            call SetECdrain(SaltOUT/(GetDrain()*Equiv))
        else
            compi = compi + 1
            celi = ActiveCells(GetCompartment_i(compi))
            if (celi < GetSoilLayer_SCP1(GetCompartment_Layer(compi))) then
                mm1 = GetSoilLayer_Dx(GetCompartment_Layer(compi))*1000._dp &
                        * GetCompartment_Thickness(compi) &
                        * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
            else
                mm1 = 2._dp*GetSoilLayer_Dx(GetCompartment_Layer(compi)) &
                        *1000._dp*GetCompartment_Thickness(compi) &
                        * (1._dp &
                          - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                      /100._dp)
            end if
            call SetCompartment_Salt(compi, celi, &
                                     GetCompartment_Salt(compi, celi) &
                                         + ECsubdrain*SubDrain*Equiv)
            Salt_temp = GetCompartment_Salt(compi, celi)
            Depo_temp = GetCompartment_Depo(compi, celi)
            call SaltSolutionDeposit(mm1, Salt_temp, Depo_temp)
            call SetCompartment_Salt(compi, celi, Salt_temp)
            call SetCompartment_Depo(compi, celi, Depo_temp)
        end if
    end if

    contains

    subroutine Mixing(Dif, mm1, mm2, Salt1, Salt2, Depo1, Depo2)
        real(dp), intent(in) :: Dif
        real(dp), intent(in) :: mm1
        real(dp), intent(in) :: mm2
        real(dp), intent(inout) :: Salt1
        real(dp), intent(inout) :: Salt2
        real(dp), intent(inout) :: Depo1
        real(dp), intent(inout) :: Depo2

        real(dp) :: EC1, EC2, ECmix

        call SaltSolutionDeposit(mm1, Salt1, Depo1)
        EC1 = Salt1/(mm1*Equiv)
        call SaltSolutionDeposit(mm2, Salt2, Depo2)
        EC2 = Salt2/(mm2*Equiv)
        ECmix = (EC1*mm1+EC2*mm2)/(mm1+mm2)
        EC1 = EC1 + (ECmix-EC1)*Dif
        EC2 = EC2 + (ECmix-EC2)*Dif
        Salt1 = EC1*mm1*Equiv
        call SaltSolutionDeposit(mm1, Salt1, Depo1)
        Salt2 = EC2*mm2*Equiv
        call SaltSolutionDeposit(mm2, Salt2, Depo2)
    end subroutine Mixing


    subroutine MoveSaltTo(Compx, celx, DS)
        type(CompartmentIndividual), intent(inout) :: Compx
        integer(int32), intent(in) :: celx
        real(dp), intent(in) :: DS

        real(dp) :: mmx
        integer(int32) :: celx_local

        celx_local = celx
        if (DS >= epsilon(0._dp)) then
            Compx%Salt(celx_local) = Compx%Salt(celx_local) + DS
            mmx = GetSoilLayer_Dx(Compx%Layer)*1000._dp*Compx%Thickness &
                    * (1._dp - GetSoilLayer_GravelVol(Compx%Layer)/100._dp)
            if (celx_local == GetSoilLayer_SCP1(Compx%Layer)) then
                mmx = 2._dp*mmx
            end if
            call SaltSolutionDeposit(mmx, Compx%Salt(celx_local), &
                                     Compx%Depo(celx_local))
        else
            celx_local = GetSoilLayer_SCP1(Compx%Layer)
            Compx%Salt(celx_local) = Compx%Salt(celx_local) + DS
            mmx = 2._dp*GetSoilLayer_Dx(Compx%Layer)*1000._dp*Compx%Thickness &
                    * (1._dp - GetSoilLayer_GravelVol(Compx%Layer)/100._dp)
            call SaltSolutionDeposit(mmx, Compx%Salt(celx_local), &
                                     Compx%Depo(celx_local))
            mmx = mmx/2._dp
            do while (Compx%Salt(celx_local) < 0._dp) 
                Compx%Salt(celx_local-1) = Compx%Salt(celx_local-1) &
                                           + Compx%Salt(celx_local)
                Compx%Salt(celx_local) = 0._dp
                celx_local = celx_local - 1
                call SaltSolutionDeposit(mmx, Compx%Salt(celx_local), &
                                         Compx%Depo(celx_local))
            end do
        end if
    end subroutine MoveSaltTo

end subroutine calculate_saltcontent 



subroutine calculate_Extra_runoff(InfiltratedRain, InfiltratedIrrigation, &
                                  InfiltratedStorage, SubDrain)
    real(dp), intent(inout) :: InfiltratedRain
    real(dp), intent(inout) :: InfiltratedIrrigation
    real(dp), intent(inout) :: InfiltratedStorage
    real(dp), intent(inout) :: SubDrain

    real(dp) :: FracSubDrain

    InfiltratedStorage = 0._dp
    InfiltratedRain = GetRain() - GetRunoff()
    if (InfiltratedRain > 0._dp) then
        FracSubDrain = SubDrain/InfiltratedRain
    else
        FracSubDrain = 0._dp
    end if
    if ((GetIrrigation()+InfiltratedRain) &
            > GetSoilLayer_InfRate(GetCompartment_Layer(1))) then
        if (GetIrrigation() > GetSoilLayer_InfRate(GetCompartment_Layer(1))) then
            InfiltratedIrrigation = GetSoilLayer_InfRate(GetCompartment_Layer(1))
            call SetRunoff(GetRain() + (GetIrrigation()-InfiltratedIrrigation))
            InfiltratedRain = 0._dp
            SubDrain = 0._dp
        else
            InfiltratedIrrigation = GetIrrigation()
            InfiltratedRain = GetSoilLayer_InfRate(GetCompartment_Layer(1)) &
                                - InfiltratedIrrigation
            SubDrain = FracSubDrain*InfiltratedRain
            call SetRunoff(GetRain() - InfiltratedRain)
        end if
    else
        InfiltratedIrrigation = GetIrrigation()
    end if
end subroutine calculate_Extra_runoff


subroutine calculate_surfacestorage(InfiltratedRain, InfiltratedIrrigation, &
                                    InfiltratedStorage, ECinfilt, SubDrain, &
                                    dayi)
    real(dp), intent(inout) :: InfiltratedRain
    real(dp), intent(inout) :: InfiltratedIrrigation
    real(dp), intent(inout) :: InfiltratedStorage
    real(dp), intent(inout) :: ECinfilt
    real(dp), intent(in) :: SubDrain
    integer(int32), intent(in) :: dayi

    real(dp) :: Sum
    real(dp) :: ECw

    InfiltratedRain = 0._dp
    InfiltratedIrrigation = 0._dp
    if (GetRainRecord_DataType() == datatype_Daily) then
        Sum = GetSurfaceStorage() + GetIrrigation() + GetRain()
    else
        Sum = GetSurfaceStorage() + GetIrrigation() + GetRain() &
              - GetRunoff() - SubDrain
    end if
    if (Sum > 0._dp) then
        ! quality of irrigation water
        if (dayi < GetCrop_Day1()) then
            ECw = GetIrriECw_PreSeason()
        else
            ECw = GetSimulation_IrriECw()
            if (dayi > GetCrop_DayN()) then
                ECw = GetIrriECw_PostSeason()
            end if
        end if
        ! quality of stored surface water
        call SetECstorage((GetECstorage() &
                            * GetSurfaceStorage() &
                            + ECw*GetIrrigation()) /Sum)
        ! quality of infiltrated water (rain and/or irrigation and/or stored surface water)
        ECinfilt = GetECstorage()
        ! surface storage
        if (Sum > GetSoilLayer_InfRate(GetCompartment_Layer(1))) then
            InfiltratedStorage = GetSoilLayer_InfRate(GetCompartment_Layer(1))
            call SetSurfaceStorage(Sum - InfiltratedStorage)
        else
            if (GetRainRecord_DataType() == datatype_Daily) then
                InfiltratedStorage = Sum
            else
                InfiltratedStorage = GetSurfaceStorage() + GetIrrigation()
                InfiltratedRain = GetRain() - GetRunoff()
            end if
            call SetSurfaceStorage(0._dp)
        end if
        ! extra run-off
        if (GetSurfaceStorage() > (GetManagement_BundHeight()*1000._dp)) then
            call SetRunoff(GetRunoff() &
                            + (GetSurfaceStorage() &
                            - GetManagement_BundHeight()*1000._dp))
            call SetSurfaceStorage(GetManagement_BundHeight()*1000._dp)
        end if
    else
        InfiltratedStorage = 0._dp
        call SetECstorage(0._dp)
    end if
end subroutine calculate_surfacestorage



subroutine calculate_infiltration(InfiltratedRain, InfiltratedIrrigation, &
                                  InfiltratedStorage, SubDrain)
    real(dp), intent(inout) :: InfiltratedRain
    real(dp), intent(inout) :: InfiltratedIrrigation
    real(dp), intent(inout) :: InfiltratedStorage
    real(dp), intent(inout) :: SubDrain

    integer(int32) :: compi, layeri, pre_comp
    real(dp) :: RunoffIni, amount_still_to_store, factor, &
                delta_theta_nul, delta_theta_SAT, theta_nul, &
                drain_max, diff, excess
    real(dp) :: EffecRain, Zr, depthi, DeltaZ, StorableMM


    ! calculate_infiltration 
    ! A -  INFILTRATION versus STORAGE in Rootzone (= EffecRain)
    if (GetRainRecord_DataType() == datatype_Daily) then
        amount_still_to_store = InfiltratedRain + InfiltratedIrrigation &
                                + InfiltratedStorage
        EffecRain = 0._dp
    else
        amount_still_to_store = InfiltratedIrrigation + InfiltratedStorage
        EffecRain = InfiltratedRain - SubDrain
    end if

    ! B - INFILTRATION through TOP soil surface
    if (amount_still_to_store > 0._dp) then
        RunoffIni = GetRunoff()
        compi = 0
        
        loop1: do
            compi = compi + 1
            layeri = GetCompartment_Layer(compi)
            
            !1. Calculate multiplication factor
            !====================================
            factor = calculate_factor(layeri, compi)
            
            !2. Calculate theta nul
            !========================
            delta_theta_nul = amount_still_to_store &
                             /(1000._dp * GetCompartment_Thickness(compi) &
                              * (1._dp-GetSoilLayer_GravelVol(layeri)/100._dp))
            delta_theta_SAT = calculate_delta_theta(&
                                GetSoilLayer_SAT(layeri)/100._dp, &
                                GetSoilLayer_FC(layeri)/100._dp, &
                                layeri)
            
            if (delta_theta_nul < delta_theta_SAT) then
                theta_nul = calculate_theta(delta_theta_nul, &
                                            GetSoilLayer_FC(layeri)/100._dp, &
                                            layeri)
                if (theta_nul <= (GetCompartment_FCadj(compi)/100._dp)) then
                    theta_nul = GetCompartment_FCadj(compi)/100._dp
                    delta_theta_nul = calculate_delta_theta( &
                                        theta_nul, &
                                        GetSoilLayer_FC(layeri)/100._dp, &
                                        layeri)
                end if
                if (theta_nul > GetSoilLayer_SAT(layeri)/100._dp) then
                    theta_nul = GetSoilLayer_SAT(layeri)/100._dp
                end if
            else
                theta_nul = GetSoilLayer_SAT(layeri)/100._dp
                delta_theta_nul = delta_theta_SAT
            end if
            
            
            !3. Calculate drain max
            !========================
            drain_max = factor * delta_theta_nul * 1000._dp &
                            * GetCompartment_Thickness(compi) &
                            * (1._dp-GetSoilLayer_GravelVol(layeri)/100._dp)
            if ((GetCompartment_fluxout(compi) + drain_max) &
                        > GetSoilLayer_InfRate(layeri)) then
                drain_max = GetSoilLayer_InfRate(layeri) &
                            - GetCompartment_fluxout(compi)
            end if
            
            
            !4. Store water
            !================
            diff = theta_nul - GetCompartment_theta(compi)
            if (diff > 0._dp) then
                call SetCompartment_theta(compi, GetCompartment_theta(compi) &
                           + amount_still_to_store &
                             /(1000._dp * GetCompartment_Thickness(compi) &
                                 * (1._dp &
                                    - GetSoilLayer_GravelVol(layeri)/100._dp)))
                if (GetCompartment_theta(compi) > theta_nul) then
                    amount_still_to_store = (GetCompartment_theta(compi) &
                                                - theta_nul) &
                               * 1000._dp &
                               * GetCompartment_Thickness(compi) &
                               * (1._dp-GetSoilLayer_GravelVol(layeri)/100._dp)
                    call SetCompartment_theta(compi, theta_nul)
                else
                    amount_still_to_store = 0.0_dp
                end if
            end if
            call SetCompartment_fluxout(compi, GetCompartment_fluxout(compi) &
                                               + amount_still_to_store)
            
            
            !5. Redistribute excess
            !========================
            excess = amount_still_to_store - drain_max
            if (excess < 0._dp) then
                excess = 0._dp
            end if
            amount_still_to_store = amount_still_to_store - excess
            
            if (excess > 0._dp) then
                pre_comp = compi + 1
                loop2: do
                    pre_comp = pre_comp - 1
                    layeri = GetCompartment_Layer(pre_comp)
                    call SetCompartment_fluxout(pre_comp, &
                                    GetCompartment_fluxout(pre_comp) &
                                                           - excess)
                    call SetCompartment_theta(&
                            pre_comp, GetCompartment_theta(pre_comp) &
                               + excess/(1000._dp &
                                  * GetCompartment_Thickness(pre_comp) &
                                  * (1._dp &
                        - GetSoilLayer_GravelVol(GetCompartment_Layer(pre_comp))&
                                                                    /100._dp)))
                    if (GetCompartment_theta(pre_comp) &
                            > GetSoilLayer_SAT(layeri)/100._dp) then
                        excess = (GetCompartment_theta(pre_comp) &
                            - GetSoilLayer_SAT(layeri)/100._dp) * 1000._dp &
                                * GetCompartment_Thickness(pre_comp) &
                                * (1._dp &
                        -GetSoilLayer_GravelVol(GetCompartment_Layer(pre_comp))&
                                                                      /100._dp)
                        call SetCompartment_theta( &
                                pre_comp, &
                                GetSoilLayer_SAT(layeri)/100._dp)
                    else
                        excess = 0.0_dp
                    end if
                    if ((excess == epsilon(0._dp)) .or. (pre_comp == 1)) exit loop2
                end do loop2
                if (excess > 0._dp) then
                    call SetRunoff(GetRunoff() + excess)
                end if
            end if
            
            if ((amount_still_to_store <= epsilon(0._dp)) &
                    .or. (compi == GetNrCompartments())) exit loop1
        end do loop1
        if (amount_still_to_store > 0._dp) then
            call SetDrain(GetDrain() + amount_still_to_store)
        end if
        
        !6. Adjust infiltrated water
        !=============================
        if (GetRunoff() > RunoffIni) then
            if (GetManagement_Bundheight() >= 0.01_dp) then
                call SetSurfaceStorage(GetSurfaceStorage() &
                                        + (GetRunoff() &
                                        - RunoffIni))
                InfiltratedStorage = InfiltratedStorage &
                                     - (GetRunoff()-RunoffIni)
                if (GetSurfaceStorage() &
                            > GetManagement_BundHeight()*1000._dp) then
                    call SetRunoff(RunoffIni &
                                   + (GetSurfaceStorage() &
                                        - GetManagement_BundHeight()*1000._dp))
                    call SetSurfaceStorage(GetManagement_BundHeight()*1000._dp)
                else
                    call SetRunoff(RunoffIni)
                end if
            else
                InfiltratedRain = InfiltratedRain - (GetRunoff()-RunoffIni)
                if (InfiltratedRain < 0._dp) then
                    InfiltratedIrrigation = InfiltratedIrrigation &
                                            + InfiltratedRain
                    InfiltratedRain = 0._dp
                end if
            end if
            
            ! INFILTRATION through TOP soil surface 
        end if
    end if
        
        
    ! C - STORAGE in Subsoil (= SubDrain)
    if (SubDrain > 0._dp) then
        amount_still_to_store = SubDrain
        
        ! Where to store 
        Zr = GetRootingDepth()
        if (Zr <= 0._dp) then
            Zr = GetSimulParam_EvapZmax()/100._dp
        end if
        compi = 0
        depthi = 0._dp
        loop3: do
            compi = compi + 1
            depthi = depthi + GetCompartment_Thickness(compi)
            if ((depthi >= Zr) &
                .or. (compi >= GetNrCompartments())) exit loop3
        end do loop3
        if (depthi > Zr) then
            DeltaZ = (depthi - Zr)
        else
            DeltaZ = 0._dp
        end if
        
        ! Store 
        do while((amount_still_to_store > 0._dp) &
                .and. ((compi < GetNrCompartments()) &
                    .or. (DeltaZ > 0._dp))) 
            if (DeltaZ == epsilon(0._dp)) then
                compi = compi + 1
                DeltaZ = GetCompartment_Thickness(compi)
            end if
            StorableMM = (GetSoilLayer_SAT(GetCompartment_Layer(compi))&
                                                            /100._dp &
                            - GetCompartment_Theta(compi)) * 1000._dp &
                                 * DeltaZ * (1._dp &
                     - GetSoilLayer_GravelVol(GetCompartment_Layer(compi))&
                                                                 /100._dp)
            if (StorableMM > amount_still_to_store) then
               call SetCompartment_theta(&
                      compi, &
                      GetCompartment_Theta(compi) &
                       + (amount_still_to_store)&
                          /(1000._dp*GetCompartment_Thickness(compi) &
                            * (1._dp &
                    - GetSoilLayer_GravelVol(GetCompartment_Layer(compi))&
                                                                /100._dp)))
                amount_still_to_store = 0._dp
            else
                amount_still_to_store = amount_still_to_store - StorableMM
                call SetCompartment_theta(&
                        compi, &
                        GetCompartment_Theta(compi) &
                        + (StorableMM)/(1000._dp &
                            * GetCompartment_Thickness(compi) &
                            * (1._dp &
                     - GetSoilLayer_GravelVol(GetCompartment_Layer(compi))&
                                                                /100._dp)))
            end if
            DeltaZ = 0._dp
            if (amount_still_to_store &
                  > GetSoilLayer_InfRate(GetCompartment_Layer(compi))) then
                SubDrain = SubDrain &
                            - (amount_still_to_store &
                        - GetSoilLayer_InfRate(GetCompartment_Layer(compi)))
                EffecRain = EffecRain &
                            + (amount_still_to_store &
                        - GetSoilLayer_InfRate(GetCompartment_Layer(compi)))
                amount_still_to_store = GetSoilLayer_InfRate(&
                                            GetCompartment_Layer(compi))
            end if
        end do
        
        ! excess 
        if (amount_still_to_store > 0._dp) then
            call SetDrain(GetDrain() + amount_still_to_store)
        end if
        ! STORAGE in Subsoil (= SubDrain) 
    end if
        
    ! D - STORAGE in Rootzone (= EffecRain)
    if (EffecRain > 0._dp) then
        Zr = GetRootingDepth()
        if (Zr <= epsilon(0._dp)) then
            Zr = GetSimulParam_EvapZmax()/100._dp
        end if
        amount_still_to_store = EffecRain
        
        ! Store 
        ! step 1 fill to FC (from top to bottom) 
        compi = 0
        depthi = 0._dp
        loop4: do
            compi = compi + 1
            depthi = depthi + GetCompartment_Thickness(compi)
            if (depthi <= Zr) then
                DeltaZ = GetCompartment_Thickness(compi)
            else
                DeltaZ = GetCompartment_Thickness(compi) &
                         - (depthi-Zr)
            end if
            StorableMM = (GetCompartment_FCadj(compi)/100._dp &
                            - GetCompartment_Theta(compi))*1000._dp*DeltaZ &
                            * (1._dp &
                      - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                  /100._dp)
            if (StorableMM < 0._dp) then
                StorableMM = 0._dp
            end if
            if (StorableMM > amount_still_to_store) then
                call SetCompartment_theta(&
                        compi, &
                        GetCompartment_Theta(compi) &
                        + amount_still_to_store &
                            /(1000._dp*GetCompartment_Thickness(compi) &
                              *(1._dp &
                       - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                 /100._dp)))
                amount_still_to_store = 0._dp
            elseif (StorableMM > 0._dp) then
                call SetCompartment_theta(&
                        compi, &
                        GetCompartment_Theta(compi) &
                        + StorableMM &
                            /(1000._dp*GetCompartment_Thickness(compi) &
                                * (1._dp &
                    - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                              /100._dp)))
                amount_still_to_store = amount_still_to_store - StorableMM
            end if
            if ((depthi >= Zr) &
                    .or. (compi >= GetNrCompartments()) &
                    .or. (amount_still_to_store <= epsilon(0._dp))) &
                            exit loop4
        end do loop4
        
        ! step 2 fill to SATURATION (from bottom to top) 
        if (amount_still_to_store > 0._dp) then
            loop5: do
                if (depthi > Zr) then
                    DeltaZ = GetCompartment_Thickness(compi) - (depthi-Zr)
                else
                    DeltaZ = GetCompartment_Thickness(compi)
                end if
                StorableMM = (GetSoilLayer_SAT(GetCompartment_Layer(compi)) &
                                                                   /100._dp &
                             - GetCompartment_Theta(compi))*1000._dp*DeltaZ &
                                * (1._dp &
                      - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                  /100._dp)
                if (StorableMM < 0._dp) then
                    StorableMM = 0._dp
                end if
                if (StorableMM > amount_still_to_store) then
                    call SetCompartment_theta(&
                            compi, &
                            GetCompartment_theta(compi) &
                            + amount_still_to_store &
                                /(1000._dp*GetCompartment_Thickness(compi) &
                                    * (1._dp &
                      - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                /100._dp)))
                    amount_still_to_store = 0._dp
                elseif (StorableMM > 0._dp) then
                    call SetCompartment_theta(&
                            compi, &
                            GetCompartment_Theta(compi) &
                            + StorableMM &
                                /(1000._dp*GetCompartment_Thickness(compi) &
                                    *(1._dp &
                      - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                /100._dp)))
                    amount_still_to_store = amount_still_to_store &
                                           - StorableMM
                end if
                compi = compi - 1
                depthi = depthi - GetCompartment_Thickness(compi)
                if ((compi == 0) &
                    .or. (amount_still_to_store <= epsilon(0._dp))) &
                            exit loop5
            end do loop5
        end if
        
        ! excess 
        if (amount_still_to_store > 0._dp) then
            if (InfiltratedRain > 0._dp) then
                InfiltratedRain = InfiltratedRain - amount_still_to_store
            end if
            if (GetManagement_Bundheight() >= 0.01_dp) then
                call SetSurfaceStorage(GetSurfaceStorage() &
                                      + amount_still_to_store)
                if (GetSurfaceStorage() &
                        > (GetManagement_BundHeight()*1000._dp)) then
                    call SetRunoff(GetRunoff() &
                                   + (GetSurfaceStorage() &
                                   - GetManagement_BundHeight()*1000._dp))
                    call SetSurfaceStorage(GetManagement_BundHeight() &
                                                            *1000._dp)
                end if
            else
                call SetRunoff(GetRunoff() + amount_still_to_store)
            end if
        end if
        ! STORAGE in Rootzone (= EffecRain) 
    end if


    contains

    real(dp) function Calculate_factor(layeri, compi)
        integer(int32), intent(in) :: layeri
        integer(int32), intent(in) :: compi

        real(dp) :: delta_theta_SAT
 
        delta_theta_SAT = calculate_delta_theta(GetSoilLayer_SAT(layeri)/100._dp, &
                                                GetSoilLayer_FC(layeri)/100._dp, &
                                                layeri)
        if (delta_theta_SAT > 0._dp) then
            Calculate_factor = GetSoilLayer_InfRate(layeri)&
                                /(delta_theta_SAT * 1000._dp &
                                    * GetCompartment_Thickness(compi) &
                                    * (1._dp-GetSoilLayer_GravelVol(layeri) &
                                                                    /100._dp))
        else
            Calculate_factor = 1._dp
        end if
    end function Calculate_factor 

end subroutine calculate_infiltration


subroutine EffectSoilFertilitySalinityStress(StressSFadjNEW, Coeffb0Salt, &
                                             Coeffb1Salt, Coeffb2Salt, &
                                             NrDayGrow, StressTotSaltPrev, &
                                             VirtualTimeCC)
    integer(int8), intent(inout) :: StressSFadjNEW
    real(dp), intent(in) :: Coeffb0Salt, Coeffb1Salt, Coeffb2Salt
    integer(int32), intent(in) :: NrDayGrow
    real(dp), intent(in) :: StressTotSaltPrev
    integer(int32), intent(in) :: VirtualTimeCC

    type(rep_EffectStress) :: FertilityEffectStress, SalinityEffectStress
    real(dp) :: SaltStress, CCxRedD
    integer(int8) :: CCxRed
    real(dp) :: ECe_temp, ECsw_temp, ECswFC_temp, KsSalt_temp
    integer(int8) :: RedCGC_temp, RedCCX_temp
    integer(int32) :: Crop_DaysToFullCanopySF_temp
    type(rep_EffectStress) :: EffectStress_temp

    if (GetSimulation_SalinityConsidered()) then
        ECe_temp = GetRootZoneSalt_ECe()
        ECsw_temp = GetRootZoneSalt_ECsw()
        ECswFC_temp = GetRootZoneSalt_ECswFC()
        KsSalt_temp = GetRootZoneSalt_KsSalt()
        call DetermineRootZoneSaltContent(GetRootingDepth(), &
                                          ECe_temp, ECsw_temp, &
                                          ECswFC_temp, KsSalt_temp)
        call SetRootZoneSalt_ECe(ECe_temp)
        call SetRootZoneSalt_ECsw(ECsw_temp)
        call SetRootZoneSalt_ECswFC(ECswFC_temp)
        call SetRootZoneSalt_KsSalt(KsSalt_temp)
        SaltStress = (NrDayGrow*StressTotSaltPrev + 100._dp &
                            *(1._dp-GetRootZoneSalt_KsSalt())) &
                     /(NrDayGrow+1._dp)
    else
        SaltStress = 0._dp
    end if
    if ((VirtualTimeCC < GetCrop_DaysToGermination()) &
            .or. (VirtualTimeCC > (GetCrop_DayN()-GetCrop_Day1())) &
            .or. (GetSimulation_Germinate() .eqv. .false.) &
            .or. ((StressSFAdjNEW == 0) .and. (SaltStress <= 0.1_dp))) then
        ! no soil fertility and salinity stress
        EffectStress_temp = GetSimulation_EffectStress()
        call NoEffectStress(EffectStress_temp)
        call SetSimulation_EffectStress(EffectStress_temp)
        call SetCrop_DaysToFullCanopySF(GetCrop_DaysToFullCanopy())
        if (GetCrop_ModeCycle() == modeCycle_GDDays) then
            call SetCrop_GDDaysToFullCanopySF(GetCrop_GDDaysToFullCanopy())
        end if
    else
        ! Soil fertility
        if (StressSFAdjNEW == 0) then
            call NoEffectStress(FertilityEffectStress)
        else
            call CropStressParametersSoilFertility(GetCrop_StressResponse(), &
                                                   StressSFAdjNEW, &
                                                   FertilityEffectStress)
        end if
        ! Soil Salinity
        CCxRedD = real(roundc(Coeffb0Salt + Coeffb1Salt * SaltStress &
                              + Coeffb2Salt * SaltStress * SaltStress, &
                                                      mold=1), kind=dp)
        if ((CCxRedD < 0._dp) &
                .or. (SaltStress <= 0.1_dp) &
                .or. (GetSimulation_SalinityConsidered() .eqv. .false.)) then
            call NoEffectStress(SalinityEffectStress)
        else
            if ((CCxRedD > 100._dp) .or. (SaltStress >= 99.9_dp)) then
                CCxRed = 100._dp
            else
                CCxRed = real(roundc(CCxRedD, mold=1), kind=dp)
            end if
            call CropStressParametersSoilSalinity(CCxRed, &
                                                  GetCrop_CCsaltDistortion(), &
                                                  GetCrop_CCo(), &
                                                  GetCrop_CCx(), &
                                                  GetCrop_CGC(), &
                                                  GetCrop_GDDCGC(), &
                                                  GetCrop_DeterminancyLinked(), &
                                                  GetCrop_DaysToFullCanopy(), &
                                                  GetCrop_DaysToFlowering(), &
                                                  GetCrop_LengthFlowering(), &
                                                  GetCrop_DaysToHarvest(), &
                                                  GetCrop_GDDaysToFullCanopy(), &
                                                  GetCrop_GDDaysToFlowering(), &
                                                  GetCrop_GDDLengthFlowering(), &
                                                  GetCrop_GDDaysToHarvest(), &
                                                  GetCrop_ModeCycle(), &
                                                  SalinityEffectStress)
        end if
        ! Assign integrated effect of the stresses
        call SetSimulation_EffectSTress_RedWP(FertilityEffectStress%RedWP)
        call SetSimulation_EffectSTress_RedKsSto(SalinityEffectStress%RedKsSto)
        if (FertilityEffectStress%RedCGC > SalinityEffectStress%RedCGC) then
            call SetSimulation_EffectSTress_RedCGC(FertilityEffectStress%RedCGC)
        else
            call SetSimulation_EffectSTress_RedCGC(SalinityEffectStress%RedCGC)
        end if
        if (FertilityEffectStress%RedCCX > SalinityEffectStress%RedCCX) then
            call SetSimulation_EffectSTress_RedCCX(FertilityEffectStress%RedCCX)
        else
            call SetSimulation_EffectSTress_RedCCX(SalinityEffectStress%RedCCX)
        end if
        if (FertilityEffectStress%CDecline > SalinityEffectStress%CDecline) then
            call SetSimulation_EffectSTress_CDecline(FertilityEffectStress%CDecline)
        else
            call SetSimulation_EffectSTress_CDecline(SalinityEffectStress%CDecline)
        end if
        ! adjust time to maximum canopy cover
        RedCGC_temp = GetSimulation_EffectStress_RedCGC()
        RedCCX_temp = GetSimulation_EffectStress_RedCCX()
        Crop_DaysToFullCanopySF_temp = GetCrop_DaysToFullCanopySF()
        call TimeToMaxCanopySF(GetCrop_CCo(), GetCrop_CGC(), GetCrop_CCx(), &
                               GetCrop_DaysToGermination(), &
                               GetCrop_DaysToFullCanopy(), &
                               GetCrop_DaysToSenescence(), &
                               GetCrop_DaysToFlowering(), &
                               GetCrop_LengthFlowering(), &
                               GetCrop_DeterminancyLinked(), &
                               Crop_DaysToFullCanopySF_temp, RedCGC_temp, &
                               RedCCX_temp, StressSFAdjNEW)
        call SetSimulation_EffectStress_RedCGC(RedCGC_temp)
        call SetSimulation_EffectStress_RedCCX(RedCCX_temp)
        call SetCrop_DaysToFullCanopySF(Crop_DaysToFullCanopySF_temp)
        if (GetCrop_ModeCycle() == modeCycle_GDDays) then
            if ((GetManagement_FertilityStress() /= 0._dp) &
                    .or. (SaltStress /= 0._dp)) then
                call SetCrop_GDDaysToFullCanopySF(&
                             GrowingDegreeDays(GetCrop_DaysToFullCanopySF(), &
                                               GetCrop_Day1(), &
                                               GetCrop_Tbase(), &
                                               GetCrop_Tupper(), &
                                               GetSimulParam_Tmin(), &
                                               GetSimulParam_Tmax()))
            else
                call SetCrop_GDDaysToFullCanopySF(GetCrop_GDDaysToFullCanopy())
            end if
        end if
    end if

    contains

    subroutine NoEffectStress(TheEffectStress)
        type(rep_EffectStress), intent(inout) :: TheEffectStress

        TheEffectStress%RedCGC = 0._dp
        TheEffectStress%RedCCX = 0._dp
        TheEffectStress%RedWP = 0._dp
        TheEffectStress%CDecline = 0._dp
        TheEffectStress%RedKsSto = 0._dp
    end subroutine NoEffectStress

end subroutine EffectSoilFertilitySalinityStress


subroutine PrepareStage1()
    type(rep_Soil) :: Soil_temp

    Soil_temp = GetSoil()

    if (GetSurfaceStorage() > 0.0000001_dp) then
        call SetSimulation_EvapWCsurf(Soil_temp%REW*1._dp)
    else
        call SetSimulation_EvapWCsurf(GetRain() + GetIrrigation() - GetRunOff())
        if (GetSimulation_EvapWCsurf() > Soil_temp%REW) then
            call SetSimulation_EvapWCsurf(Soil_temp%REW*1._dp)
        end if
    end if
    call SetSimulation_EvapStartStg2(int(undef_int,kind=int8))
    call SetSimulation_EvapZ(EvapZmin/100._dp)

end subroutine PrepareStage1


real(dp) function WCEvapLayer(Zlayer, AtTheta)
    real(dp), intent(in) :: Zlayer
    integer(intEnum), intent(in) :: AtTheta

    real(dp) :: Ztot, Wx, fracZ
    integer(int32) :: compi

    Wx = 0.0_dp
    Ztot = 0.0_dp
    compi = 0
    do while ((abs(Zlayer-Ztot) > 0.0001_dp) &
            .and. (compi < GetNrCompartments())) 
        compi = compi + 1
        if ((Ztot + GetCompartment_Thickness(compi)) > Zlayer) then
            fracZ = (Zlayer - Ztot)/(GetCompartment_Thickness(compi))
        else
            fracZ = 1._dp
        end if
        select case (AtTheta)
            case(whichtheta_AtSAT)
            Wx = Wx + 10._dp &
                    * GetSoilLayer_SAT(GetCompartment_Layer(compi)) &
                    * fracZ * GetCompartment_Thickness(compi) &
                    * (1._dp &
                        - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                    /100._dp)
            case (whichtheta_AtFC)
            Wx = Wx + 10._dp &
                    * GetSoilLayer_FC(GetCompartment_Layer(compi)) &
                    * fracZ * GetCompartment_Thickness(compi) &
                    * (1._dp &
                        - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                    /100._dp)
            case (whichtheta_AtWP)
            Wx = Wx + 10._dp &
                    * GetSoilLayer_WP(GetCompartment_Layer(compi)) &
                    * fracZ * GetCompartment_Thickness(compi) &
                    * (1._dp &
                        - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                    /100._dp)
            case default
                Wx = Wx + 1000._dp &
                        * GetCompartment_Theta(compi) * fracZ &
                        * GetCompartment_Thickness(compi) &
                        * (1._dp &
                            - GetSoilLayer_GravelVol(GetCompartment_Layer(compi)) &
                                                                        /100._dp)
        end select
        Ztot = Ztot + fracZ * GetCompartment_Thickness(compi)
    end do
    WCEvapLayer = Wx
end function WCEvapLayer



subroutine PrepareStage2()

    integer(intEnum) :: AtTheta
    real(dp) :: WSAT, WFC, Wact

    call SetSimulation_EvapZ(EvapZmin/100)
    AtTheta = whichtheta_AtSat
    WSAT = WCEvapLayer(GetSimulation_EvapZ(), AtTheta)
    AtTheta = whichtheta_AtFC
    WFC = WCEvapLayer(GetSimulation_EvapZ(), AtTheta)
    AtTheta = whichtheta_AtAct
    Wact = WCEvapLayer(GetSimulation_EvapZ(), AtTheta)
    call SetSimulation_EvapStartStg2(roundc(100._dp &
          * (Wact - (WFC-GetSoil_REW()))/(WSAT-(WFC-GetSoil_REW())), &
                                                      mold=1_int8))
    if (GetSimulation_EvapStartStg2() < 0) then
        call SetSimulation_EvapStartStg2(0_int8)
    end if
end subroutine PrepareStage2


subroutine CalculateEvaporationSurfaceWater()

    real(dp) :: SaltSurface

    if (GetSurfaceStorage() > GetEpot()) then
        SaltSurface = GetSurfaceStorage()*GetECstorage()*Equiv
        call SetEact(GetEpot())
        call SetSurfaceStorage(GetSurfaceStorage() - GetEact())
        call SetECstorage(SaltSurface/(GetSurfaceStorage()*Equiv)) 
            ! salinisation of surface storage layer
    else
        call SetEact(GetSurfaceStorage())
        call SetSurfaceStorage(0._dp)
        call SetSimulation_EvapWCsurf(real(GetSoil_REW(), kind=dp))
        call SetSimulation_EvapZ(EvapZmin/100._dp)
        if (GetSimulation_EvapWCsurf() < 0.0001_dp) then
            call PrepareStage2()
        else
            call SetSimulation_EvapStartStg2(int(undef_int, kind=int8))
        end if
    end if
end subroutine CalculateEvaporationSurfaceWater




subroutine AdjustEpotMulchWettedSurface(dayi, EpotTot, Epot, EvapWCsurface)
    integer(int32), intent(in) :: dayi
    real(dp), intent(in) :: EpotTot
    real(dp), intent(inout) :: Epot
    real(dp), intent(inout) :: EvapWCsurface

    real(dp) :: EpotIrri

    ! 1. Mulches (reduction of EpotTot to Epot)
    if (GetSurfaceStorage() <= 0.000001_dp) then
        if (dayi < GetCrop_Day1()) then ! before season
            Epot = EpotTot &
                    * (1._dp - (GetManagement_EffectMulchOffS()/100._dp) &
                               *(GetManagement_SoilCoverBefore()/100._dp))
        else
            if (dayi < GetCrop_Day1()+GetCrop_DaysToHarvest()) then ! in season
                Epot = EpotTot &
                        * (1._dp &
                            - (GetManagement_EffectMulchInS()/100._dp) &
                             * (GetManagement_Mulch()/100._dp))
            else
                Epot = EpotTot &
                        * (1._dp &
                            - (GetManagement_EffectMulchOffS()/100._dp) &
                             * (GetManagement_SoilCoverAfter()/100._dp))
            end if
        end if
    else
        Epot = EpotTot ! flooded soil surface
    end if


    ! 2a. Entire soil surface wetted ?
    if (GetIrrigation() > 0._dp) then
        ! before season
        if ((dayi < GetCrop_Day1()) &
            .and. (GetSimulParam_IrriFwOffSeason() < 100)) then
            call SetEvapoEntireSoilSurface(.false.)
        end if
        ! in season
        if ((dayi >= GetCrop_Day1()) &
            .and. (dayi < GetCrop_Day1()+GetCrop_DaysToHarvest()) &
            .and. (GetSimulParam_IrriFwInSeason() < 100)) then
            call SetEvapoEntireSoilSurface(.false.)
        end if
        ! after season
        if ((dayi >= GetCrop_Day1()+GetCrop_DaysToHarvest()) &
            .and.(GetSimulParam_IrriFwOffSeason() < 100)) then
            call SetEvapoEntireSoilSurface(.false.)
        end if
    end if
    if ((GetRain() > 1._dp) .or. (GetSurfaceStorage() > 0._dp)) then
        call SetEvapoEntireSoilSurface(.true.)
    end if
    if ((dayi >= GetCrop_Day1()) &
        .and. (dayi < GetCrop_Day1()+GetCrop_DaysToHarvest()) &
        .and. (GetIrriMode() == IrriMode_Inet)) then
        call SetEvapoEntireSoilSurface(.true.)
    end if

    ! 2b. Correction for Wetted surface by Irrigation
    if (.not.GetEvapoEntireSoilSurface()) then
        if ((dayi >= GetCrop_Day1()) &
            .and. (dayi < GetCrop_Day1()+GetCrop_DaysToHarvest())) then
            ! in season
            EvapWCsurface = EvapWCsurface &
                            * (GetSimulParam_IrriFwInSeason()/100._dp)
            EpotIrri = EpotTot * (GetSimulParam_IrriFwInSeason()/100._dp)
        else
            ! off-season
            EvapWCsurface = EvapWCsurface &
                            * (GetSimulParam_IrriFwOffSeason()/100._dp)
            EpotIrri = EpotTot * (GetSimulParam_IrriFwOffSeason()/100._dp)
        end if
        if (GetEact() > EpotIrri) then
            EpotIrri = GetEact()  ! Eact refers to the previous day
        end if
        if (EpotIrri < Epot) then
            Epot = Epotirri
        end if
    end if
end subroutine AdjustEpotMulchWettedSurface


subroutine ConcentrateSalts()

    integer(int32) :: compi, celWet, celi
    real(dp) :: SaltTot, mm
    real(dp) :: Salt_temp, Depo_temp

    do compi = 1, GetNrCompartments() 
        SaltTot = 0.0_dp
        celWet = ActiveCells(GetCompartment_i(compi))
        if (celWet < GetSoilLayer_SCP1(GetCompartment_Layer(compi))) then
            do celi = (celWet+1), GetSoilLayer_SCP1(GetCompartment_Layer(compi)) 
                SaltTot = SaltTot + GetCompartment_Salt(compi, celi)&
                          + GetCompartment_Depo(compi, celi)
                call SetCompartment_Salt(compi, celi, 0.0_dp)
                call SetCompartment_Depo(compi, celi, 0.0_dp)
            end do
        end if
        if (SaltTot > 0.0_dp) then
            call SetCompartment_Salt(compi, celWet, &
                GetCompartment_Salt(compi, celWet) + SaltTot)
            mm = GetSoilLayer_Dx(GetCompartment_Layer(compi))*1000.0_dp&
                 * GetCompartment_Thickness(compi)&
                 * (1 - GetSoilLayer_GravelVol(GetCompartment_Layer(compi))&
                        / 100.0_dp)
            Salt_temp = GetCompartment_Salt(compi, celWet)
            Depo_temp = GetCompartment_Depo(compi, celWet)
            call SaltSolutionDeposit(mm, Salt_temp, Depo_temp)
            call SetCompartment_Salt(compi, celWet, Salt_temp)
            call SetCompartment_Depo(compi, celWet, Depo_temp)
        end if
    end do
end subroutine ConcentrateSalts


!-----------------------------------------------------------------------------
! end BUDGET_module
!-----------------------------------------------------------------------------

end module ac_simul
