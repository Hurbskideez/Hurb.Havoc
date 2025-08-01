untyped

global function MpTitanweaponArcMine_Init
global function OnWeaponPrimaryAttack_titanweapon_arc_mine
global function OnProjectileCollision_titanweapon_arc_mine
global function OnWeaponAttemptOffhandSwitch_titanweapon_arc_mine

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_arc_mine
#endif // #if SERVER

const FUSE_TIME = 2.5 //Applies once the grenade has stuck to a player.
const FUSE_TIME_EXTENDED = 5 //Applies once the grenade has stuck to a surface.
const MINE_TRIGGER_DELAY = 0.5

const STICKY_MINE_FIELD_ACTIVATION_TIME = 0.5 //After landing

const FX_EMP_BODY_HUMAN			= $"P_emp_body_human"
const FX_EMP_BODY_TITAN			= $"P_emp_body_titan"

function MpTitanweaponArcMine_Init()
{
	PrecacheWeapon("mp_titanweapon_arc_mine")
	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_arc_mine, ArcMineOnDamage )
	#endif
}

var function OnWeaponPrimaryAttack_titanweapon_arc_mine( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
	{
		vector offset = Vector( 30.0, 6.0, -4.0 )
		if ( weapon.IsWeaponInAds() )
			offset = Vector( 30.0, 0.0, -3.0 )
		vector attackPos = player.OffsetPositionFromView( attackParams[ "pos" ], offset )	// forward, right, up
		FireGrenade( weapon, attackParams )
	}
	//Add the helper
	weapon.AddMod("instant_burst_helper")
	//Check to remove the helper
	int ammoPerShot = weapon.GetAmmoPerShot()
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	if (currAmmo <= ammoPerShot / 3)
		weapon.RemoveMod("instant_burst_helper")

	return weapon.GetWeaponInfoFileKeyField( "ammo_per_shot" ) / 3
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_arc_mine( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	//Add the helper
	weapon.AddMod("instant_burst_helper")
	//Check to remove the helper
	int ammoPerShot = weapon.GetAmmoPerShot()
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	if (currAmmo <= ammoPerShot / 3)
		weapon.RemoveMod("instant_burst_helper")
	FireGrenade( weapon, attackParams, false )
}
#endif // #if SERVER

bool function OnWeaponAttemptOffhandSwitch_titanweapon_arc_mine( entity weapon )
{
	int ammoPerShot = weapon.GetAmmoPerShot()
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	if ( currAmmo < ammoPerShot )
		return false

	return true
}

function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, isNPCFiring = false )
{
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0.0 , damageType, damageType, isNPCFiring, true, false )

	if ( nade )
	{
		if(weapon.HasMod("magnetic_mines"))
			nade.InitMagnetic( 1000.0, "Explo_MGL_MagneticAttract" )

		#if SERVER
			EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
			Grenade_Init( nade, weapon )
		#else
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif
	}
}

void function OnProjectileCollision_titanweapon_arc_mine( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	bool didStick = PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
	if ( !didStick )
		return
	projectile.s.collisionNormal <- normal

	//This is what happens when you try to put a disc on something with a spherical hitbox
	//projectile.SetOrigin(projectile.GetOrigin() - normal*2)

	entity weaponOwner = projectile.GetOwner()
	vector origin = projectile.GetOrigin()

	vector startAngle = projectile.GetAngles() + <90, 0, 0>
	projectile.SetAngles( startAngle )

	#if SERVER
		EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )
		if ( hitEnt.IsPlayer() || hitEnt.IsNPC() )
		{
			thread UpdateArcMineField(weaponOwner, projectile, origin, FUSE_TIME)
			thread DetonateStickyAfterTime( projectile, FUSE_TIME, normal )
		}
		else
		{
			thread UpdateArcMineField(weaponOwner, projectile, origin, FUSE_TIME_EXTENDED)
			thread DetonateStickyAfterTime( projectile, FUSE_TIME_EXTENDED, normal )
			thread ArcMineProximityTrigger( projectile )
		}
	#endif
}

#if SERVER
void function UpdateArcMineField( entity owner, entity pylon, vector origin, float duration )
{
  pylon.EndSignal( "OnDestroy" )
  float endTime = Time() + duration

	while ( Time() < endTime )
	{
		WaitFrame()
		origin = pylon.GetOrigin()
		ArcMineFieldDamage( owner, pylon, origin )
	}
}

function ArcMineFieldDamage( entity owner, entity pylon, vector origin )
{
    RadiusDamage(
        origin,									// center
        owner,									// attacker
        pylon,									// inflictor
        25,					// damage
        10,					// damageHeavyArmor
        10,		// innerRadius
        25,				// outerRadius
        SF_ENVEXPLOSION_NO_DAMAGEOWNER,			// flags
        0,										// distanceFromAttacker
        0,					                    // explosionForce
        DF_ELECTRICAL | DF_STOPS_TITAN_REGEN,	// scriptDamageFlags
        eDamageSourceId.mp_titanweapon_arc_mine )			// scriptDamageSourceIdentifier
}

function ArcMineProximityTrigger( entity nade )
{
	//Hack, shouldn't be necessary with the IsValid check in OnProjectileCollision.
	if( !IsValid( nade ) )
		return

	nade.EndSignal( "OnDestroy" )
	EmitSoundOnEntity( nade, "Wpn_TripleThreat_Grenade_MineAttach" )

	wait STICKY_MINE_FIELD_ACTIVATION_TIME

	EmitSoundOnEntity( nade, "Weapon_Vortex_Gun.ExplosiveWarningBeep" )
	local rangeCheck = PROX_MINE_RANGE
	while( 1 )
	{
		local origin = nade.GetOrigin()
		int team = nade.GetTeam()

		local entityArray = GetScriptManagedEntArrayWithinCenter( level._proximityTargetArrayID, team, origin, PROX_MINE_RANGE )
		foreach( entity ent in entityArray )
		{
			if ( IsAlive( ent ) )
			{
				wait MINE_TRIGGER_DELAY
				vector normal = Vector( 0, 0, 1 )
				if( "collisionNormal" in nade.s )
					normal = expect vector( nade.s.collisionNormal )
				nade.GrenadeExplode( normal )
				return
			}
		}
		WaitFrame()
	}
}
#endif // SERVER

#if SERVER
// need this so grenade can use the normal to explode
void function DetonateStickyAfterTime( entity projectile, float delay, vector normal )
{
	wait delay
	if ( IsValid( projectile ) )
		projectile.GrenadeExplode( normal )
}
#endif

#if SERVER
void function ArcMineOnDamage( entity ent, var damageInfo )
{
	vector pos = DamageInfo_GetDamagePosition( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	vector origin = DamageInfo_GetDamagePosition( damageInfo )

	if ( ent.IsPlayer() || ent.IsNPC() )
	{
		entity entToSlow = ent
		entity soul = ent.GetTitanSoul()

		if ( soul != null )
			entToSlow = soul

		if ( DamageInfo_GetDamage( damageInfo ) <= 0 )
			return

		const ARC_TITAN_EMP_DURATION			= 1.5
		const ARC_TITAN_EMP_FADEOUT_DURATION	= 0.35

		StatusEffect_AddTimed( entToSlow, eStatusEffect.move_slow, 0.2, 1.5, 1.0 )
		StatusEffect_AddTimed( ent, eStatusEffect.emp, 0.5, ARC_TITAN_EMP_DURATION, ARC_TITAN_EMP_FADEOUT_DURATION )

		string tag = ""
		asset effect

		if ( ent.IsTitan() )
		{
			tag = "exp_torso_front"
			effect = FX_EMP_BODY_TITAN
		}
		else if ( ChestFocusTarget( ent ) )
		{
			tag = "CHESTFOCUS"
			effect = FX_EMP_BODY_HUMAN
		}
		else if ( IsAirDrone( ent ) )
		{
			tag = "HEADSHOT"
			effect = FX_EMP_BODY_HUMAN
		}
		else if ( IsGunship( ent ) )
		{
			tag = "ORIGIN"
			effect = FX_EMP_BODY_TITAN
		}

		if ( tag != "" )
		{
			float duration = 2.0
			thread EMP_FX( effect, ent, tag, duration )
		}

		if ( ent.IsTitan() )
		{
			if ( ent.IsPlayer() )
			{
			 	EmitSoundOnEntityOnlyToPlayer( ent, ent, "titan_energy_bulletimpact_3p_vs_1p" )
				EmitSoundOnEntityExceptToPlayer( ent, ent, "titan_energy_bulletimpact_3p_vs_3p" )
			}
			else
			{
			 	EmitSoundOnEntity( ent, "titan_energy_bulletimpact_3p_vs_3p" )
			}
		}
		else
		{
			if ( ent.IsPlayer() )
			{
			 	EmitSoundOnEntityOnlyToPlayer( ent, ent, "flesh_lavafog_deathzap_3p" )
				EmitSoundOnEntityExceptToPlayer( ent, ent, "flesh_lavafog_deathzap_1p" )
			}
			else
			{
			 	EmitSoundOnEntity( ent, "flesh_lavafog_deathzap_1p" )
			}
		}
	}
}

bool function ChestFocusTarget( entity ent )
{
	if ( IsSpectre( ent ) )
		return true
	if ( IsStalker( ent ) )
		return true
	if ( IsSuperSpectre( ent ) )
		return true
	if ( IsGrunt( ent ) )
		return true
	if ( IsPilot( ent ) )
		return true

	return false
}
#endif
