untyped

global function MpTitanweaponArcCharge_Init
global function OnWeaponPrimaryAttack_titanweapon_arc_charge
global function OnProjectileCollision_titanweapon_arc_charge
global function OnWeaponAttemptOffhandSwitch_titanweapon_arc_charge

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_arc_charge
#endif // #if SERVER

const FUSE_TIME = 0.5 //Applies once the grenade has stuck to a player.
const FUSE_TIME_EXTENDED = 5 //Applies once the grenade has stuck to a surface.
const MINE_TRIGGER_DELAY = 0.5

const STICKY_MINE_FIELD_ACTIVATION_TIME = 0.5 //After landing

const FX_EMP_BODY_HUMAN			= $"P_emp_body_human"
const FX_EMP_BODY_TITAN			= $"P_emp_body_titan"

function MpTitanweaponArcCharge_Init()
{
	PrecacheWeapon("mp_titanweapon_arc_charge")
	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_arc_charge, ArcChargeOnDamage )
	#endif
}

var function OnWeaponPrimaryAttack_titanweapon_arc_charge( entity weapon, WeaponPrimaryAttackParams attackParams )
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

	return weapon.GetWeaponInfoFileKeyField( "ammo_per_shot" )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_arc_charge( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	FireGrenade( weapon, attackParams, false )
}
#endif // #if SERVER

bool function OnWeaponAttemptOffhandSwitch_titanweapon_arc_charge( entity weapon )
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

void function OnProjectileCollision_titanweapon_arc_charge( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	if ( hitEnt && !hitEnt.IsWorld() )
		return

	bool didStick = PlantStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
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

			thread UpdateArcChargeField(weaponOwner, projectile, origin, 5, 0.85)
			//thread DetonateStickyAfterTime( projectile, 0.85*5, normal )
	#endif
}

#if SERVER
void
function UpdateArcChargeField(entity owner, entity projectile, vector origin, int burstCount, float delay)
{
	projectile.EndSignal( "OnDestroy" )
	float duration = delay * burstCount
	float endTime = Time() + duration

  	for(int i = 0; i < burstCount; i++) {
		wait(delay)
		origin = projectile.GetOrigin()
		ArcChargeFieldDamage( owner, projectile, origin )

		var impact_effect_table = projectile.ProjectileGetWeaponInfoFileKeyField( "impact_effect_table" )
		if ( impact_effect_table != null )
		{
			string fx = expect string( impact_effect_table )
			PlayImpactFXTable( origin, projectile.GetOwner(), fx )
		}
	}
	projectile.SetProjectilTrailEffectIndex( 1 )
	projectile.Dissolve( ENTITY_DISSOLVE_CHAR, < 0, 0, 0 >, 0 )
}

function ArcChargeFieldDamage( entity owner, entity pylon, vector origin )
{
    RadiusDamage(
        origin,									// center
        owner,									// attacker
        pylon,									// inflictor
        250,					// damage
        1000,					// damageHeavyArmor
        100,		// innerRadius
        250,				// outerRadius
        0,			// flags
        0,										// distanceFromAttacker
        0,					                    // explosionForce
        DF_ELECTRICAL | DF_STOPS_TITAN_REGEN,	// scriptDamageFlags
        eDamageSourceId.mp_titanweapon_arc_charge )			// scriptDamageSourceIdentifier
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
void function ArcChargeOnDamage( entity ent, var damageInfo )
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
