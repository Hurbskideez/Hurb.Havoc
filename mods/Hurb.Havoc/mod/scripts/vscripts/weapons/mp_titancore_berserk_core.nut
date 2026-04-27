global function OnWeaponPrimaryAttack_DoNothingBerserk

global function Berserk_Core_Init
#if SERVER
global function Berserk_Core_UseMeter
#endif

global function OnCoreCharge_Berserk_Core
global function OnCoreChargeEnd_Berserk_Core
global function OnAbilityStart_Berserk_Core

const float USE_COST_FRAC = 0.3

const float BERSERK_CORE_MAX_PUSH = 1900
const float BERSERK_CORE_MAX_PUSH_HUMANSIZED = 1400
const float BERSERK_CORE_MAX_PUSH_ADD = 100 // The maximum amount of speed past push speed it can give the target (if they were moving in the same direction)

void function Berserk_Core_Init()
{
	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.melee_titan_punch_havoc, BerserkCoreOnDamage )
	#endif

    PrecacheWeapon("mp_titancore_berserk_core")
}

var function OnWeaponPrimaryAttack_DoNothingBerserk( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return 0
}

bool function OnCoreCharge_Berserk_Core( entity weapon )
{
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

#if SERVER
	entity owner = weapon.GetWeaponOwner()
	string swordCoreSound_1p
	string swordCoreSound_3p
	if ( weapon.HasMod( "fd_duration" ) )
	{
		swordCoreSound_1p = "Titan_Ronin_Sword_Core_Activated_Upgraded_1P"
		swordCoreSound_3p = "Titan_Ronin_Sword_Core_Activated_Upgraded_3P"
	}
	else
	{
		swordCoreSound_1p = "Titan_Ronin_Sword_Core_Activated_1P"
		swordCoreSound_3p = "Titan_Ronin_Sword_Core_Activated_3P"
	}
	if ( owner.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, swordCoreSound_1p )
		EmitSoundOnEntityExceptToPlayer( owner, owner, swordCoreSound_3p )
	}
	else
	{
		EmitSoundOnEntity( weapon, swordCoreSound_3p )
	}
#endif

	return true
}

void function OnCoreChargeEnd_Berserk_Core( entity weapon )
{
	#if SERVER
	entity owner = weapon.GetWeaponOwner()
	OnAbilityChargeEnd_TitanCore( weapon )
	#endif
}

var function OnAbilityStart_Berserk_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnAbilityStart_TitanCore( weapon )

	entity owner = weapon.GetWeaponOwner()

	if ( !owner.IsTitan() )
		return 0

	if ( !IsValid( owner ) )
		return

	entity offhandWeapon = owner.GetOffhandWeapon( OFFHAND_MELEE )
	if ( !IsValid( offhandWeapon ) )
		return 0

#if SERVER
	if ( owner.IsPlayer() )
	{
		owner.Server_SetDodgePower( 100.0 )
		owner.SetPowerRegenRateScale( 10 )
		owner.SetDodgePowerDelayScale( 0.1 )
		GivePassive( owner, ePassives.PAS_FUSION_CORE )
		GivePassive( owner, ePassives.PAS_BERSERKER )
	}

	entity soul = owner.GetTitanSoul()
	if ( soul != null )
	{
		entity titan = soul.GetTitan()

		if ( titan.IsNPC() )
		{
			titan.SetAISettings( "npc_titan_stryder_leadwall_shift_core" )
			titan.EnableNPCMoveFlag( NPCMF_PREFER_SPRINT )
			titan.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, false )
			AddAnimEvent( titan, "shift_core_use_meter", Berserk_Core_UseMeter_NPC )
		}

		titan.GetOffhandWeapon( OFFHAND_MELEE ).AddMod( "berserker" )

		titan.SetActiveWeaponByName( "melee_titan_punch_havoc" )

		entity mainWeapon = titan.GetMainWeapons()[0]
		mainWeapon.AllowUse( false )

		int endlessStatusEffectHandle = StatusEffect_AddEndless( titan, eStatusEffect.speed_boost, 0.5 )
		thread BerserkThink( titan, endlessStatusEffectHandle )
	}

	float delay = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
	thread Berserk_Core_End( weapon, owner, delay )
#endif

	return 1
}

#if SERVER
void function BerserkThink( entity player, int endlessStatusEffectHandle )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnChangedPlayerClass" )
	player.EndSignal( "CoreEnd" )
	if ( endlessStatusEffectHandle != 0 )
		player.EndSignal( "StopEndlessStim" )

	OnThreadEnd(
		function() : ( player, endlessStatusEffectHandle )
		{
			if ( !IsValid( player ) )
				return

			if ( endlessStatusEffectHandle != 0 )
				StatusEffect_Stop( player, endlessStatusEffectHandle )
		}
	)

	WaitForever()
}

void function Berserk_Core_End( entity weapon, entity player, float delay )
{
	weapon.EndSignal( "OnDestroy" )

	if ( player.IsNPC() && !IsAlive( player ) )
		return

	player.EndSignal( "OnDestroy" )
	if ( IsAlive( player ) )
		player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )
	player.EndSignal( "DisembarkingTitan" )
	player.EndSignal( "OnSyncedMelee" )
	player.EndSignal( "InventoryChanged" )

	OnThreadEnd(
	function() : ( weapon, player )
		{
			OnAbilityEnd_Berserk_Core( weapon, player )

			if ( IsValid( player ) )
			{
				entity soul = player.GetTitanSoul()
				if ( soul != null )
					CleanupCoreEffect( soul )
			}
		}
	)

	entity soul = player.GetTitanSoul()
	if ( soul == null )
		return

	while ( 1 )
	{
		if ( soul.GetCoreChargeExpireTime() <= Time() )
			break;
		wait 0.1
	}
}

void function OnAbilityEnd_Berserk_Core( entity weapon, entity player )
{
	OnAbilityEnd_TitanCore( weapon )

	if ( player.IsPlayer() )
	{
		player.SetPowerRegenRateScale( 1.0 )
		player.SetDodgePowerDelayScale( 1.0 )
		EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Ronin_Sword_Core_Deactivated_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "Titan_Ronin_Sword_Core_Deactivated_3P" )
		int conversationID = GetConversationIndex( "swordCoreOffline" )
		Remote_CallFunction_Replay( player, "ServerCallback_PlayTitanConversation", conversationID )
	}
	else
	{
		DeleteAnimEvent( player, "shift_core_use_meter" )
		EmitSoundOnEntity( player, "Titan_Ronin_Sword_Core_Deactivated_3P" )
	}

	RestorePlayerWeapons( player )
}

void function RestorePlayerWeapons( entity player )
{
	if ( !IsValid( player ) )
		return

	if ( player.IsNPC() && !IsAlive( player ) )
		return // no need to fix up dead NPCs

	entity soul = player.GetTitanSoul()

	if ( player.IsPlayer() )
	{
		TakePassive( player, ePassives.PAS_FUSION_CORE )
		TakePassive( player, ePassives.PAS_BERSERKER )

		soul = GetSoulFromPlayer( player )
	}

	if ( soul != null )
	{
		entity titan = soul.GetTitan()

		entity meleeWeapon = titan.GetOffhandWeapon( OFFHAND_MELEE )
		if ( IsValid( meleeWeapon ) )
		{
			meleeWeapon.RemoveMod( "berserker" )
		}

		array<entity> mainWeapons = titan.GetMainWeapons()
		if ( mainWeapons.len() > 0 )
		{
			entity mainWeapon = titan.GetMainWeapons()[0]
			mainWeapon.AllowUse( true )
		}

		if ( titan.IsNPC() )
		{
			string settings = GetSpawnAISettings( titan )
			if ( settings != "" )
				titan.SetAISettings( settings )

			titan.DisableNPCMoveFlag( NPCMF_PREFER_SPRINT )
			titan.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, true )
		}
	}
}

void function BerserkCoreOnDamage( entity ent, var damageInfo )
{
	printt("I AM RUNNIN")
	vector pos = DamageInfo_GetDamagePosition( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	vector origin = DamageInfo_GetDamagePosition( damageInfo )

	if (!PlayerHasPassive(attacker, ePassives.PAS_BERSERKER))
		return

	DamageInfo_SetDamageSourceIdentifier( damageInfo, eDamageSourceId.mp_titancore_berserk_core)

	Berserk_Core_UseMeter( attacker )

	BerserkCoreKnockback( ent, damageInfo )
}

void function BerserkCoreKnockback( entity victim, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return

	/*Stagger NPC titans first
	if ( !victim.IsPlayer() )
	{
		if ( victim.IsTitan() && !victim.ContextAction_IsActive() && victim.IsInterruptable() )
		{
			thread BlastShield_StaggerTitan( victim )
		}
	}*/

	//we only want to knock back players and titans, stagger everything else (including AI titans)
	if(!victim.IsTitan() && !victim.IsPlayer() )
		return

	entity weapon = DamageInfo_GetWeapon( damageInfo )
	//Get Push force depending on whether the damaged entity is a titan or not
	float pushForce = victim.IsTitan() ? BERSERK_CORE_MAX_PUSH : BERSERK_CORE_MAX_PUSH_HUMANSIZED
	//Get push direction
    vector pushDir = Normalize( victim.GetOrigin() - attacker.GetOrigin() )

	//Get Victim's velocity and adjust to their current velocity
	float velInDir = victim.GetVelocity().Dot( pushDir )
	if ( velInDir + pushForce > pushForce + BERSERK_CORE_MAX_PUSH_ADD )
		pushForce = max( 0.0, pushForce + BERSERK_CORE_MAX_PUSH_ADD - velInDir )

	PushEntWithVelocity( victim, pushDir * pushForce )
}

void function Berserk_Core_UseMeter( entity player )
{
	entity soul = player.GetTitanSoul()
	float curTime = Time()
	float remainingTime = soul.GetCoreChargeExpireTime() - curTime

	if ( remainingTime > 0 )
	{
		float startTime = soul.GetCoreChargeStartTime()
		float duration = soul.GetCoreUseDuration()

		float useTime = duration * USE_COST_FRAC
		remainingTime = max( remainingTime - useTime, 0 )

		soul.SetTitanSoulNetFloat( "coreExpireFrac", remainingTime / duration )
		soul.SetTitanSoulNetFloatOverTime( "coreExpireFrac", 0.0, remainingTime )
		soul.SetCoreChargeExpireTime( remainingTime + curTime )
	}
}

void function Berserk_Core_UseMeter_NPC( entity npc )
{
	Berserk_Core_UseMeter( npc )
}
#endif
