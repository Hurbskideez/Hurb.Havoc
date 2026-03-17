untyped

global function MpTitanweaponBlastShield_Init

global function OnWeaponActivate_titanweapon_blast_shield
global function OnWeaponDeactivate_titanweapon_blast_shield
global function OnWeaponCustomActivityStart_titanweapon_blast_shield
global function OnWeaponVortexHitBullet_titanweapon_blast_shield
global function OnWeaponVortexHitProjectile_titanweapon_blast_shield
global function OnWeaponPrimaryAttack_titanweapon_blast_shield
global function OnWeaponChargeBegin_titanweapon_blast_shield
global function OnWeaponChargeEnd_titanweapon_blast_shield
global function OnWeaponAttemptOffhandSwitch_titanweapon_blast_shield
global function OnWeaponOwnerChanged_titanweapon_blast_shield

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_blast_shield
#endif

const float BLAST_SHIELD_DEACTIVATION_COST = 0.1
const float BLAST_SHIELD_MIN_CHARGE = 0.375 // ( Charge Time / Shield Uptime )
const int BLAST_SHIELD_FOV = 120
const int BLAST_SHIELD_RADIUS = 150

const float BLAST_CHARGE_TIME = 1.5
const float BLAST_COOLDOWN_TIME = 0.5
const float BLAST_COOLDOWN_DELAY = 0.0
const float BLAST_WARNING_TIME = 0.0

//Titan Push Values
//Min 600 Max 1200
//Pilot Push Values
//Min 4000 Min 7000
const float BLAST_SHIELD_MIN_DAMAGE_FRAC = 0.25
const float BLAST_SHIELD_MIN_PUSH = 600
const float BLAST_SHIELD_MIN_PUSH_HUMANSIZED = 4000
const float BLAST_SHIELD_MAX_PUSH = 1200
const float BLAST_SHIELD_MAX_PUSH_HUMANSIZED = 7000
const float BLAST_SHIELD_MAX_PUSH_ADD = 100 // The maximum amount of speed past push speed it can give the target (if they were moving in the same direction)

function MpTitanweaponBlastShield_Init()
{
	PrecacheWeapon( "mp_titanweapon_blast_shield" )
	RegisterSignal( "ChargeEnd" )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_blast_shield, BlastShield_DamagedEntity )
	#endif
}

void function OnWeaponOwnerChanged_titanweapon_blast_shield( entity weapon, WeaponOwnerChangedParams changeParams )
{
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.fxChargingFPControlPoint <- $"wpn_vortex_chargingCP_titan_FP"
		weapon.s.fxChargingFPControlPointReplay <- $"wpn_vortex_chargingCP_titan_FP_replay"
		weapon.s.fxChargingControlPoint <- $"wpn_vortex_chargingCP_titan"
		weapon.s.fxBulletHit <- $"wpn_vortex_shield_impact_titan"

		weapon.s.fxChargingFPControlPointBurn <- $"wpn_vortex_chargingCP_mod_FP"
		weapon.s.fxChargingFPControlPointReplayBurn <- $"wpn_vortex_chargingCP_mod_FP_replay"
		weapon.s.fxChargingControlPointBurn <- $"wpn_vortex_chargingCP_mod"
		weapon.s.fxBulletHitBurn <- $"wpn_vortex_shield_impact_mod"

		weapon.s.fxElectricalExplosion <- $"P_impact_exp_emp_med_air"

		weapon.s.endChargeTime <- 0.0
		weapon.s.initialized <- true
	}
}

void function OnWeaponActivate_titanweapon_blast_shield( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	weapon.w.startChargeTime = 0.0
	weapon.s.endChargeTime = 0.0

	// just for NPCs (they don't do the deploy event)
	if ( !weaponOwner.IsPlayer() )
		StartBlastShield( weapon )
	else
		PlayerUsedOffhand( weaponOwner, weapon )
}

void function OnWeaponDeactivate_titanweapon_blast_shield( entity weapon )
{
	EndVortex( weapon )
	#if CLIENT
		weapon.Signal( "WeaponDeactivateEvent" )
	#endif
}

void function OnWeaponCustomActivityStart_titanweapon_blast_shield( entity weapon )
{
	EndVortex( weapon )
}

function StartBlastShield( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	#if CLIENT
	if ( weaponOwner != GetLocalViewPlayer() )
		return
	if ( IsFirstTimePredicted() )
		Rumble_Play( "rumble_titan_vortex_start", {} )
	#endif

	int sphereRadius = BLAST_SHIELD_RADIUS
	int bulletFOV = BLAST_SHIELD_FOV

	//ApplyActivationCost( weapon, BLAST_SHIELD_DEACTIVATION_COST )

	CreateVortexSphere( weapon, false, false, sphereRadius, bulletFOV )
	BlastShield_EnableVortexSphere( weapon )
	weapon.w.startChargeTime = Time()

	#if SERVER
		thread ForceReleaseOnPlayerEject( weapon )
	#endif
}

function ForceReleaseOnPlayerEject( entity weapon )
{
	weapon.EndSignal( "VortexFired" )
	weapon.EndSignal( "OnDestroy" )

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( !IsAlive( weaponOwner ) )
		return

	weaponOwner.EndSignal( "OnDeath" )

	weaponOwner.WaitSignal( "TitanEjectionStarted" )

	weapon.ForceRelease()
}

function ApplyActivationCost( entity weapon, float frac )
{
	float fracLeft = weapon.GetWeaponChargeFraction()

	if ( fracLeft + frac >= 1 )
	{
		weapon.ForceRelease()
		weapon.SetWeaponChargeFraction( 1.0 )
	}
	else
	{
		weapon.SetWeaponChargeFraction( fracLeft + frac )
	}
}

function EndVortex( entity weapon )
{
	weapon.StopWeaponSound( "vortex_shield_loop_1P" )
	weapon.StopWeaponSound( "vortex_shield_loop_3P" )
	DestroyVortexSphereFromVortexWeapon( weapon )
}

bool function OnWeaponVortexHitBullet_titanweapon_blast_shield( entity weapon, entity vortexSphere, var damageInfo )
{
	#if CLIENT
		return true
	#else
		if ( !ValidateVortexImpact( vortexSphere ) )
			return false

		entity attacker				= DamageInfo_GetAttacker( damageInfo )
		vector origin				= DamageInfo_GetDamagePosition( damageInfo )
		int damageSourceID			= DamageInfo_GetDamageSourceIdentifier( damageInfo )
		entity attackerWeapon		= DamageInfo_GetWeapon( damageInfo )
		string attackerWeaponName	= attackerWeapon.GetWeaponClassName()

		local impactData = Vortex_CreateImpactEventData( weapon, attacker, origin, damageSourceID, attackerWeaponName, "hitscan" )
		VortexDrainedByImpact( weapon, attackerWeapon, null, null )
		if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
			return true
		Vortex_SpawnHeatShieldPingFX( weapon, impactData, true )

		return true
	#endif
}

bool function OnWeaponVortexHitProjectile_titanweapon_blast_shield( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos )
{
	#if CLIENT
		return true
	#else
		if ( !ValidateVortexImpact( vortexSphere, projectile ) )
			return false

		int damageSourceID = projectile.ProjectileGetDamageSourceID()
		string weaponName = projectile.ProjectileGetWeaponClassName()

		local impactData = Vortex_CreateImpactEventData( weapon, attacker, contactPos, damageSourceID, weaponName, "projectile" )
		VortexDrainedByImpact( weapon, projectile, projectile, null )
		if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
			return true
		Vortex_SpawnHeatShieldPingFX( weapon, impactData, false )
		return true
	#endif
}

var function OnWeaponPrimaryAttack_titanweapon_blast_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	bool shouldExplode = false
	if (BlastShield_GetCharge(weapon) >= 1)
	{
		#if SERVER
			BlastShield_SetCharge( weapon, 0.0 )
		#endif
		weapon.EmitWeaponSound_1p3p( "incendiary_trap_explode_large", "heat_shield_3p_end" )
		BlastShield_Blast( weapon, attackParams )

		shouldExplode = true
	}
	EndVortex( weapon )
	FadeOutSoundOnEntity( weapon, "heat_shield_1p_start", 0.15 )
	FadeOutSoundOnEntity( weapon, "heat_shield_3p_start", 0.15 )

	return shouldExplode
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_blast_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponSound_1p3p( "heat_shield_1p_end", "heat_shield_3p_end" )
	BlastShield_Blast( weapon, attackParams )
	DestroyVortexSphereFromVortexWeapon( weapon )
	return 1
}
#endif

#if CLIENT
void function OnClientAnimEvent_titanweapon_blast_shield( entity weapon, string name )
{
	if ( name == "muzzle_flash" )
	{
		asset fpEffect = $"wpn_muzzleflash_vortex_titan_CP_FP"

		int handle
		if ( GetLocalViewPlayer() == weapon.GetWeaponOwner() )
		{
			handle = weapon.PlayWeaponEffectReturnViewEffectHandle( fpEffect, $"", "vortex_center" )
		}
		else
		{
			handle = StartParticleEffectOnEntity( weapon, GetParticleSystemIndex( fpEffect ), FX_PATTACH_POINT_FOLLOW, weapon.LookupAttachment( "vortex_center" ) )
		}

		Assert( handle )
		// This Assert isn't valid because Effect might have been culled
		// Assert( EffectDoesExist( handle ), "vortex shield OnClientAnimEvent: Couldn't find viewmodel effect handle for vortex muzzle flash effect on client " + GetLocalViewPlayer() )

		vector colorVec = GetBlastShieldCurrentColor(BlastShield_GetCharge( weapon ))
		printt(BlastShield_GetCharge( weapon ))
		EffectSetControlPointVector( handle, 1, colorVec )
	}
}
#endif

bool function OnWeaponChargeBegin_titanweapon_blast_shield( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	weapon.EmitWeaponSound("titan_ability_flamering_launch_3p")

	weapon.SetScriptTime0( Time() )

	if ( weaponOwner.IsPlayer() )
		StartBlastShield( weapon )

		float timer = BLAST_CHARGE_TIME * (1 - BlastShield_GetCharge( weapon ))
		#if SERVER
			weaponOwner.SetPlayerNetFloatOverTime("coreMeterModifier", 1.0, timer) //add a proper decay time
		#endif
		thread CookBlastShield( weapon, weaponOwner ) //WIP

	return true
}

void function CookBlastShield( entity weapon, entity weaponOwner )
{
    weaponOwner.EndSignal( "OnDeath" )
    weapon.EndSignal( "ChargeEnd" )
    weapon.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( weapon )
		{
			weapon.StopWeaponSound("Weapon_Vortex_Gun.ExplosiveWarningBeep")
			weapon.StopWeaponSound( "titan_alarm_loop" )
		}
	)

	float chargeFrac = 1 - BlastShield_GetCharge( weapon )
    float maxCookTime = chargeFrac * BLAST_CHARGE_TIME

    if ( maxCookTime - BLAST_WARNING_TIME < 0 )
    {
		weapon.EmitWeaponSound( "Weapon_Vortex_Gun.ExplosiveWarningBeep" )
		weapon.EmitWeaponSound( "titan_alarm_loop" )
		weapon.EmitWeaponSound( "weapon_titan_flamethrower_starttrigger_1p" )
		#if CLIENT
			FlashChargeCritical_Bar( weapon )
		#endif
        wait maxCookTime
    }
    else
    {
        wait( maxCookTime - BLAST_WARNING_TIME )

		weapon.EmitWeaponSound( "Weapon_Vortex_Gun.ExplosiveWarningBeep" )
		weapon.EmitWeaponSound( "titan_alarm_loop" )
		weapon.EmitWeaponSound( "weapon_titan_flamethrower_starttrigger_1p" )
		#if CLIENT
			FlashChargeCritical_Bar( weapon )
		#endif

        wait( BLAST_WARNING_TIME )

		weapon.EmitWeaponSound( "weapon_40mm_burstloader_leveltick_3" )
    }

	#if SERVER
		weapon.AddMod("charge_full")
	#endif
}

void function OnWeaponChargeEnd_titanweapon_blast_shield( entity weapon )
{
	weapon.Signal("ChargeEnd")

	printt(weapon.GetScriptTime0())
	printt(Time() -weapon.GetScriptTime0())

	weapon.StopWeaponSound("titan_ability_flamering_launch_3p")

	thread DelayCooldown(weapon, BLAST_COOLDOWN_TIME, BLAST_COOLDOWN_DELAY)

	if( !weapon.HasMod("charge_full") )
	{
		ApplyActivationCost( weapon, BLAST_SHIELD_DEACTIVATION_COST )
	}

	#if SERVER
		weapon.RemoveMod("charge_full")
	#endif


}

void function DelayCooldown(entity weapon, float cooldown, float delay)
{
	entity weaponOwner = weapon.GetWeaponOwner()
	#if SERVER
		weaponOwner.SetPlayerNetFloatOverTime("coreMeterModifier", BlastShield_GetCharge(weapon), 0.0)
	#endif

	wait delay

	float timer = cooldown * BlastShield_GetCharge( weapon )
	#if SERVER
		weaponOwner.SetPlayerNetFloatOverTime("coreMeterModifier", 0.0, timer) //add a proper decay time
	#endif
}

function BlastShield_Blast( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.s.endChargeTime = Time()

	entity owner = weapon.GetWeaponOwner()
	float maxDistance	= weapon.GetMaxDamageFarDist()
	float maxAngle = 16.5

	array<entity> ignoredEntities 	= [ owner ]
	int traceMask 					= TRACE_MASK_SHOT
	int visConeFlags				= VIS_CONE_ENTS_TEST_HITBOXES | VIS_CONE_ENTS_CHECK_SOLID_BODY_HIT | VIS_CONE_ENTS_APPOX_CLOSEST_HITBOX

	entity antilagPlayer
	if ( owner.IsPlayer() )
	{
		if ( owner.IsPhaseShifted() )
			return;

		antilagPlayer = owner
	}

	// Fires an invisible bullet that does nothing to ping radar
	weapon.FireWeaponBullet_Special( attackParams.pos, attackParams.dir, 1, 0, true, true, false, true, true, false, true )

	#if SERVER
	array<VisibleEntityInCone> results = FindVisibleEntitiesInCone( attackParams.pos, attackParams.dir, maxDistance, (maxAngle * 1.1), ignoredEntities, traceMask, visConeFlags, antilagPlayer, weapon )
	foreach ( result in results )
	{
		float angleToHitbox = 0.0
		if ( !result.solidBodyHit )
			angleToHitbox = DegreesToTarget( attackParams.pos, attackParams.dir, result.approxClosestHitboxPos )

		if ( !IsValid( result.ent ) )
			continue

		float damage = CalcWeaponDamage( owner, result.ent, weapon, Distance( attackParams.pos, result.visiblePosition ), result.extraMods )

		table damageTable = {
			origin = result.visiblePosition,
			force = weapon.GetWeaponSettingFloat( eWeaponVar.impulse_force ) * attackParams.dir,
			scriptType = DF_RAGDOLL | DF_KNOCK_BACK | DF_GIB,
			damageSourceId = weapon.GetDamageSourceID(),
			weapon = weapon,
			hitbox = result.visibleHitbox
		}
		result.ent.TakeDamage( damage, owner, weapon, damageTable )
	}
	local attachmentName = "muzzle_flash"
	local attachmentIndex = weapon.LookupAttachment( attachmentName )
	Assert( attachmentIndex >= 0 )
	local muzzleOrigin = weapon.GetAttachmentOrigin( attachmentIndex )
	expect vector( muzzleOrigin )

	PlayImpactFXTable( muzzleOrigin, weapon.GetOwner(), "exp_satchel", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
	#endif
}

#if SERVER
void function BlastShield_DamagedEntity( entity victim, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return

	entity weapon = DamageInfo_GetWeapon( damageInfo )
	float minPush = victim.IsTitan() ? BLAST_SHIELD_MIN_PUSH : BLAST_SHIELD_MIN_PUSH_HUMANSIZED
	float maxPush = victim.IsTitan() ? BLAST_SHIELD_MAX_PUSH : BLAST_SHIELD_MAX_PUSH_HUMANSIZED
	float damageMultiplier = DamageInfo_GetDamage( damageInfo ) / weapon.GetWeaponSettingInt( eWeaponVar.damage_near_value_titanarmor )
	float pushAmount = GraphCapped( IsValid( weapon ) ? BlastShield_GetCharge( weapon ) : 0, 0, 1, minPush, maxPush ) * damageMultiplier
    vector pushDir = Normalize( victim.GetOrigin() - attacker.GetOrigin() )

	float velInDir = victim.GetVelocity().Dot( pushDir )
	if ( velInDir + pushAmount > maxPush + BLAST_SHIELD_MAX_PUSH_ADD )
		pushAmount = max( 0.0, maxPush + BLAST_SHIELD_MAX_PUSH_ADD - velInDir )

	if(victim.IsTitan() || victim.IsPlayer() ) //we only want to knock back players and titans
		PushEntWithVelocity( victim, pushDir * pushAmount )
}
#endif

bool function OnWeaponAttemptOffhandSwitch_titanweapon_blast_shield( entity weapon )
{
	return weapon.GetWeaponChargeFraction() < 1.0 - BLAST_SHIELD_MIN_CHARGE
}