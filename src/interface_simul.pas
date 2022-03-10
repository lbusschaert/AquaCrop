unit interface_simul;

interface

uses Global, interface_global, TempProcessing, interface_tempprocessing;

function GetCDCadjustedNoStressNew(
            constref CCx, CDC, CCxAdjusted): double;
     external 'aquacrop' name '__ac_simul_MOD_getcdcadjustednostressnew';

procedure AdjustpLeafToETo(
            constref EToMean : double;
            VAR pLeafULAct : double ;
            VAR pLeafLLAct : double);
     external 'aquacrop' name '__ac_simul_MOD_adjustpleaftoeto';


procedure DeterminePotentialBiomass(
            constref VirtualTimeCC : integer;
            constref cumGDDadjCC : double;
            constref CO2i : double;
            constref GDDayi : double;
            VAR CCxWitheredTpotNoS : double;
            VAR BiomassUnlim : double);
     external 'aquacrop' name '__ac_simul_MOD_determinepotentialbiomass';

procedure DetermineBiomassAndYield(
            constref dayi : integer;
            constref ETo : double;
            constref TminOnDay : double;
            constref TmaxOnDay : double;
            constref CO2i,GDDayi : double;
            constref Tact : double;
            constref SumKcTop : double;
            constref CGCref : double;
            constref GDDCGCref : double;
            constref Coeffb0 : double;
            constref Coeffb1 : double;
            constref Coeffb2 : double;
            constref FracBiomassPotSF : double;
            constref Coeffb0Salt : double;
            constref Coeffb1Salt : double;
            constref Coeffb2Salt : double;
            constref AverageSaltStress : double;
            constref SumGDDadjCC : double;
            constref CCtot : double;
            constref FracAssim : double;
            constref VirtualTimeCC :  integer;
            constref SumInterval :  integer;
            VAR Biomass : double;
            VAR BiomassPot : double;
            VAR BiomassUnlim,BiomassTot : double;
            VAR YieldPart : double;
            VAR WPi : double;
            VAR HItimesBEF : double;
            VAR ScorAT1 : double;
            VAR ScorAT2 : double;
            VAR HItimesAT1 : double;
            VAR HItimesAT2 : double;
            VAR HItimesAT : double;
            VAR alfa : double;
            VAR alfaMax : double;
            VAR SumKcTopStress : double;
            VAR SumKci : double;
            VAR CCxWitheredTpot : double;
            VAR CCxWitheredTpotNoS : double;
            VAR WeedRCi : double;
            VAR CCw : double;
            VAR Trws : double;
            VAR StressSFadjNEW : ShortInt;
            VAR PreviousStressLevel : ShortInt;
            VAR StoreAssimilates : boolean;
            VAR MobilizeAssimilates : boolean; 
            VAR AssimToMobilize : double;
            VAR AssimMobilized : double;
            VAR Bin : double;
            VAR Bout : double;
            VAR TESTVAL : double);
     external 'aquacrop' name '__ac_simul_MOD_determinebiomassandyield_wrap';

procedure AdjustpStomatalToETo(
            constref MeanETo : double;
            VAR pStomatULAct : double);
     external 'aquacrop' name '__ac_simul_MOD_adjuststomataltoeto';

//-----------------------------------------------------------------------------
// BUDGET_module
//-----------------------------------------------------------------------------


function calculate_delta_theta(
             constref theta, thetaAdjFC : double;
             constref NrLayer : integer): double;
     external 'aquacrop' name '__ac_simul_MOD_calculate_delta_theta';

function calculate_theta(
             constref delta_theta, thetaAdjFC : double;
             constref NrLayer : integer): double;
     external 'aquacrop' name '__ac_simul_MOD_calculate_theta';

procedure calculate_drainage();
     external 'aquacrop' name '__ac_simul_MOD_calculate_drainage';

procedure calculate_runoff(constref MaxDepth : double );
     external 'aquacrop' name '__ac_simul_MOD_calculate_runoff';

//-----------------------------------------------------------------------------
// end BUDGET_module
//-----------------------------------------------------------------------------


implementation


initialization


end.

