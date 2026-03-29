untyped

global function HavocPrecache
global function HavocEnergy_Init
global function BlastShield_GetCharge
global function BlastShield_SetCharge
global function OnWeaponPrimaryAttack_titanmelee_havoc_berserker

#if CLIENT
global function Havoc_CreateEnergyBar
global function Havoc_DestroyEnergyBar
global function FlashChargeCritical_Bar
#endif

global const int HAVOC_ENERGY_MAX = 1

#if CLIENT
struct
{
	var havocShieldChargeBarRui = null
} file
#endif

void function HavocPrecache()
{
  #if SERVER
	RegisterWeaponDamageSources(
		{
			mp_titanweapon_havoc_triplethreat = "#WPN_HAVOC_TRIPLE_THREAT"
			mp_titanweapon_shockwave = "#WPN_TITAN_SHOCKWAVE"
			mp_titanweapon_arc_charge = "#WPN_TITAN_ARC_CHARGE"
			mp_titanweapon_blast_shield = "#WPN_TITAN_BLAST_SHIELD"
			melee_titan_punch_havoc = "WPN_MELEE_TITAN_PUNCH_HAVOC"
		}
	)
	#endif

  HavocTripleThreat_Init()
  MpTitanweaponShockWave_Init()
  MpTitanweaponArcCharge_Init()
  MpTitanweaponBlastShield_Init()
  Havoc_Loadout_Util()
  PrecacheWeapon("mp_titancore_berserk_core")
  PrecacheWeapon("melee_titan_punch_havoc")
  #if CLIENT
  HavocEnergy_Init()
  #endif
}

void function HavocEnergy_Init()
{
	#if CLIENT
		AddTitanCockpitManagedRUI( Havoc_CreateEnergyBar, Havoc_DestroyEnergyBar, Havoc_ShouldCreateEnergyBar, RUI_DRAW_COCKPIT )
	#endif
}

float function BlastShield_GetCharge( entity weapon )
{
	return weapon.GetWeaponOwner().GetPlayerNetFloat("coreMeterModifier")
}

void function BlastShield_SetCharge( entity weapon, float chargeFrac )
{
	weapon.GetWeaponOwner().SetPlayerNetFloat( "coreMeterModifier", chargeFrac )
}

#if CLIENT
var function Havoc_CreateEnergyBar()
{
	Assert( file.havocShieldChargeBarRui == null )

	entity player = GetLocalViewPlayer()

	var rui = CreateTitanCockpitRui( $"ui/ion_energy_bar.rpak" )

	file.havocShieldChargeBarRui = rui

	RuiSetFloat( file.havocShieldChargeBarRui, "energyMax", HAVOC_ENERGY_MAX )
	RuiTrackFloat( file.havocShieldChargeBarRui, "energy", GetLocalViewPlayer(), RUI_TRACK_SCRIPT_NETWORK_VAR, GetNetworkedVariableIndex( "coreMeterModifier" ))

	return file.havocShieldChargeBarRui
}

void function Havoc_DestroyEnergyBar()
{
	TitanCockpitDestroyRui( file.havocShieldChargeBarRui )
	file.havocShieldChargeBarRui = null
}

bool function Havoc_ShouldCreateEnergyBar()
{
	entity player = GetLocalViewPlayer()

	if ( !IsAlive( player ) )
		return false

	array<entity> mainWeapons = player.GetMainWeapons()
	if ( mainWeapons.len() == 0 )
		return false

	/*entity primaryWeapon = mainWeapons[0]
	if ( primaryWeapon.GetWeaponInfoFileKeyField( "npc_use_check_type" ) != "shared_energy" )
		return false*/

	return true //Add proper rules later
}

void function FlashChargeCritical_Bar(entity weapon)
{
	weapon.EndSignal( "OnDestroy" )
	weapon.EndSignal( "VortexFired" )
	weapon.EndSignal( "ChargeEnd" )

	if ( file.havocShieldChargeBarRui == null )
		return

	while(true){
		WaitFrame()
		RuiSetFloat(file.havocShieldChargeBarRui, "energyNeededRatio", BlastShield_GetCharge( weapon ))
		RuiSetGameTime( file.havocShieldChargeBarRui, "energyNeededFlashStartTime", Time() )
	}

}
#endif

var function OnWeaponPrimaryAttack_titanmelee_havoc_berserker( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()
	printt("I AM ATTACKING")
    #if SERVER
        SetPlayerVelocityFromInput( player, 1000, <0,0,200> )
    #endif
	return 0
}
