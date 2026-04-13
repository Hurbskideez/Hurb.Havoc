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

const float BLAST_SHIELD_ACTIVATION_COST = 0.1
const float BLAST_SHIELD_MIN_CHARGE = 0.4 // ( Charge Time / Shield Uptime ) + Blast Shield Activation Cost
const int BLAST_SHIELD_FOV = 120
const int BLAST_SHIELD_RADIUS = 150

const float BLAST_CHARGE_TIME = 1.2
const float BLAST_COOLDOWN_TIME = 0.5
const float BLAST_COOLDOWN_DELAY = 0.5 //HACK delays the application of the Energy Bar visuals until after it hits 0, effectively removing it at full charge

const asset BLAST_SHIELD_ABSORB_FX		= $"P_wpn_HeatShield_impact"

const float BLAST_SHIELD_MAX_PUSH = 1200
const float BLAST_SHIELD_MAX_PUSH_HUMANSIZED = 950
const float BLAST_SHIELD_MAX_PUSH_ADD = 100 // The maximum amount of speed past push speed it can give the target (if they were moving in the same direction)

const KIT_SPEEDUP_TIME = 2.5

const VortexIgnoreClassnames = {
	["mp_titancore_flame_wave"] = true,
	["mp_ability_grapple"] = true,
	["mp_ability_shifter"] = true,
}

function MpTitanweaponBlastShield_Init()
{
	PrecacheWeapon( "mp_titanweapon_blast_shield" )
	RegisterSignal( "ChargeEnd" )

	PrecacheParticleSystem( $"wpn_vortex_chargingCP_mod_FP_blast" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_mod_blast")

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_blast_shield, BlastShield_DamagedEntity )
	#endif
}

void function OnWeaponOwnerChanged_titanweapon_blast_shield( entity weapon, WeaponOwnerChangedParams changeParams )
{
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.fxChargingFPControlPoint <- $"wpn_vortex_chargingCP_mod_FP_blast"
		weapon.s.fxChargingFPControlPointReplay <- $"wpn_vortex_chargingCP_mod_FP_blast"
		weapon.s.fxChargingControlPoint <- $"wpn_vortex_chargingCP_mod_blast"
		weapon.s.fxBulletHit <- BLAST_SHIELD_ABSORB_FX

		weapon.s.fxChargingFPControlPointBurn <- $"wpn_vortex_chargingCP_mod_FP_blast"
		weapon.s.fxChargingFPControlPointReplayBurn <- $"wpn_vortex_chargingCP_mod_FP_blast"
		weapon.s.fxChargingControlPointBurn <- $"wpn_vortex_chargingCP_mod_blast"
		weapon.s.fxBulletHitBurn <- BLAST_SHIELD_ABSORB_FX

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

	ApplyActivationCost( weapon, BLAST_SHIELD_ACTIVATION_COST )

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

		Vortex_SpawnHeatShieldPingFX( weapon, impactData, true )
		return TryBlastShieldAbsorb( vortexSphere, attacker, origin, damageSourceID, attackerWeapon, attackerWeaponName, "hitscan", null, null )
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

		Vortex_SpawnHeatShieldPingFX( weapon, impactData, false )
		return TryBlastShieldAbsorb( vortexSphere, attacker, contactPos, damageSourceID, projectile, weaponName, "projectile", projectile, null )
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
			weapon.StopWeaponSound( "Weapon_Vortex_Gun.ExplosiveWarningBeep" )
			weapon.StopWeaponSound( "titan_alarm_loop" )
			weapon.StopWeaponSound( "weapon_titan_flamethrower_starttrigger_1p" )
		}
	)

    wait BLAST_CHARGE_TIME

	weapon.EmitWeaponSound( "Weapon_Vortex_Gun.ExplosiveWarningBeep" )
	weapon.EmitWeaponSound( "titan_alarm_loop" )
	weapon.EmitWeaponSound( "weapon_titan_flamethrower_starttrigger_1p" )

	WaitForever()
}

void function OnWeaponChargeEnd_titanweapon_blast_shield( entity weapon )
{
	weapon.Signal("ChargeEnd")

	printt(weapon.GetScriptTime0())
	printt(Time() -weapon.GetScriptTime0())

	weapon.StopWeaponSound("titan_ability_flamering_launch_3p")

	thread DelayCooldown(weapon, BLAST_COOLDOWN_TIME, BLAST_COOLDOWN_DELAY)

	if( BlastShield_GetCharge( weapon ) == 1.0 )
		weapon.PlayWeaponEffect( $"wpn_muzzleflash_arc_cannon_FP", $"wpn_muzzleflash_arc_cannon", "vortex_center")
}

void function DelayCooldown(entity weapon, float cooldown, float delay)
{
	entity weaponOwner = weapon.GetWeaponOwner()

	if (BlastShield_GetCharge( weapon ) == 1.0)
		wait delay //this threaded delay is critical for the Blast animation to play properly, not entirely sure why

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
	float maxAngle = 10.5

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

	#if CLIENT
		FlashChargeCritical_Bar( weapon )
	#endif

	#if SERVER
		CreateShake(weapon.GetOrigin(), 180, 4, 0.5, 400)
	#endif

	if( weapon.HasMod( "pas_blast_speed_boost" ))
	{
		StatusEffect_AddTimed( owner, eStatusEffect.speed_boost, 0.35, KIT_SPEEDUP_TIME, 1.0 )
		#if SERVER
			thread AddExhaustRecyclerThrusters( owner )
		#endif
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
void function AddExhaustRecyclerThrusters( entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )

	array<entity> activeFX

	if ( player.LookupAttachment( "THRUST" ) != 0 )
	{
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_large" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "vent_right" ) ) )
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_large" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "vent_left" ) ) )

		foreach ( fx in activeFX )
		{
			if ( IsValid( fx ) )
				fx.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY)
		}
	}

	wait KIT_SPEEDUP_TIME

	OnThreadEnd(
		function() : ( activeFX )
		{
			foreach ( fx in activeFX )
			{
				if ( IsValid( fx ) )
					fx.Destroy()
			}
		}
	)
}

void function BlastShield_DamagedEntity( entity victim, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return

	//Stagger NPC titans first
	if ( !victim.IsPlayer() )
	{
		if ( victim.IsTitan() && !victim.ContextAction_IsActive() && victim.IsInterruptable() )
		{
			thread BlastShield_StaggerTitan( victim )
		}
	}

	//we only want to knock back players and titans, stagger everything else (including AI titans)
	if(!victim.IsTitan() && !victim.IsPlayer() )
		return

	entity weapon = DamageInfo_GetWeapon( damageInfo )
	//Get Push force depending on whether the damaged entity is a titan or not
	float pushForce = victim.IsTitan() ? BLAST_SHIELD_MAX_PUSH : BLAST_SHIELD_MAX_PUSH_HUMANSIZED
	//Reduce push force depending on damage dealt
	float falloffScalar = DamageInfo_GetDamage(damageInfo) / (victim.IsTitan() ? weapon.GetWeaponSettingInt(eWeaponVar.damage_near_value_titanarmor) : weapon.GetWeaponSettingInt(eWeaponVar.damage_near_value))
	float pushAmount = pushForce * falloffScalar
	//Get push direction
    vector pushDir = Normalize( victim.GetOrigin() - attacker.GetOrigin() )

	//Get Victim's velocity and adjust to their current velocity
	float velInDir = victim.GetVelocity().Dot( pushDir )
	if ( velInDir + pushAmount > pushForce + BLAST_SHIELD_MAX_PUSH_ADD )
		pushAmount = max( 0.0, pushForce + BLAST_SHIELD_MAX_PUSH_ADD - velInDir )

	PushEntWithVelocity( victim, pushDir * pushAmount )
}
#endif

bool function OnWeaponAttemptOffhandSwitch_titanweapon_blast_shield( entity weapon )
{
	return weapon.GetWeaponChargeFraction() < 1.0 - BLAST_SHIELD_MIN_CHARGE
}

#if SERVER
// this function handles all incoming vortex impact events
bool function TryBlastShieldAbsorb( entity vortexSphere, entity attacker, vector origin, int damageSourceID, entity weapon, string weaponName, string impactType, entity projectile = null, damageType = null )
{
	if ( weaponName in VortexIgnoreClassnames )
		return false

	entity vortexWeapon = vortexSphere.GetOwnerWeapon()
	entity owner = vortexWeapon.GetWeaponOwner()

	// vortex spheres tag refired projectiles with info about the original projectile for accurate duplication when re-absorbed
	if ( projectile )
	{

		// specifically for tether, since it gets moved to the vortex area and can get absorbed in the process, then destroyed
		if ( !IsValid( projectile ) )
			return false

		entity projOwner = projectile.GetOwner()
		if ( IsValid( projOwner ) && projOwner.GetTeam() == owner.GetTeam() )
			return false

		if ( projectile.proj.hasBouncedOffVortex )
			return false

		if ( projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_ignores_vortex" ) == "fall_vortex" )
		{
			vector velocity = projectile.GetVelocity()
			vector multiplier = < -0.25, -0.25, -0.25 >
			velocity = < velocity.x * multiplier.x, velocity.y * multiplier.y, velocity.z * multiplier.z >
			projectile.SetVelocity( velocity )
			projectile.proj.hasBouncedOffVortex = true
			return false
		}

		// Max projectile stat tracking
		int projectilesInVortex = 1
		projectilesInVortex += vortexWeapon.w.vortexImpactData.len()

		if ( IsValid( owner ) && owner.IsPlayer() )
		{
		 	var impact_sound_1p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_1p" )
			if ( impact_sound_1p != null )
				EmitSoundOnEntityOnlyToPlayer( vortexSphere, owner, impact_sound_1p )
		}

		var impact_sound_3p = projectile.ProjectileGetWeaponInfoFileKeyField( "vortex_impact_sound_3p" )
		if ( impact_sound_3p != null )
			EmitSoundAtPosition( TEAM_UNASSIGNED, origin, impact_sound_3p )
	}
	else
	{
		if ( IsValid( owner ) && owner.IsPlayer() )
		{
			var impact_sound_1p = GetWeaponInfoFileKeyField_Global( weaponName, "vortex_impact_sound_1p" )
			if ( impact_sound_1p != null )
				EmitSoundOnEntityOnlyToPlayer( vortexSphere, owner, impact_sound_1p )
		}

		var impact_sound_3p = GetWeaponInfoFileKeyField_Global( weaponName, "vortex_impact_sound_3p" )
		if ( impact_sound_3p != null )
			EmitSoundAtPosition( TEAM_UNASSIGNED, origin, impact_sound_3p )
	}

	local impactData = Vortex_CreateImpactEventData( vortexWeapon, attacker, origin, damageSourceID, weaponName, impactType )

	VortexDrainedByImpact( vortexWeapon, weapon, projectile, damageType )
	Vortex_NotifyAttackerDidDamage( expect entity( impactData.attacker ), owner, impactData.origin )

	if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
		return true

	if ( vortexWeapon.GetWeaponClassName() == "mp_titanweapon_heat_shield" )
		return true

	if ( !Vortex_ScriptCanHandleImpactEvent( impactData ) )
		return false

	return true
}
#endif // SERVER

function Vortex_NotifyAttackerDidDamage( entity attacker, entity vortexOwner, hitPos )
{
	if ( !IsValid( attacker ) || !attacker.IsPlayer() )
		return

	if ( !IsValid( vortexOwner ) )
		return

	Assert( hitPos )

	attacker.NotifyDidDamage( vortexOwner, 0, hitPos, 0, 0, DAMAGEFLAG_VICTIM_HAS_VORTEX, 0, null, 0 )
}

function Vortex_ScriptCanHandleImpactEvent( impactData )
{
	if ( impactData.refireBehavior == VORTEX_REFIRE_NONE )
		return false

	if ( !impactData.absorbFX )
		return false

	if ( impactData.impactType == "projectile" && !impactData.impact_effect_table )
		return false

	return true
}

void function BlastShield_StaggerTitan( entity titan )
{
	Assert ( IsNewThread(), "Must be threaded off." )
	titan.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( titan )
		{

			if ( IsValid( titan ) )
			{
				if ( titan.ContextAction_IsBusy() )
					titan.ContextAction_ClearBusy()
			}
		}
	)

	titan.ContextAction_SetBusy()
	titan.Anim_ScriptedPlayActivityByName( "ACT_FLINCH_KNOCKBACK_BACK", true, 0.1 )

	wait 2.0
}