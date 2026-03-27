untyped


global function HavocTripleThreat_Init
global function OnWeaponPrimaryAttack_titanweapon_triple_threat_havoc
global function OnProjectileCollision_titanweapon_triple_threat_havoc
global function OnWeaponChargeBegin_titanweapon_triple_threat_havoc
global function OnWeaponChargeEnd_titanweapon_triple_threat_havoc

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_triple_threat_havoc
#endif

const FX_MINE_TRAIL = $"Rocket_Smoke_Large"
const FX_MINE_LIGHT = $"P_tt_explosive_light"
const FX_MINE_GLOW = $"wpn_grenade_TT_mag"
const FX_TRIPLE_IGNITION = $"wpn_grenade_TT_activate"
const FX_TRIPLE_IGNITION_BURN = $"wpn_grenade_TT_activate"
const MIN_FUSE_TIME = 2.1
const MAX_FUSE_TIME = 2.3
const MIN_FUSE_TIME_KIT = 3.1
const MAX_FUSE_TIME_KIT = 3.3
const MAGNETISE_DELAY = 0.5

global const TRIPLE_THREAT_NUM_SHOTS = 3
global const TRIPLE_THREAT_LAUNCH_VELOCITY = 1200.0
global const TRIPLE_THREAT_MINE_FIELD_ACTIVATION_TIME = 0.5 //After landing

const TRIPLE_THREAT_MAX_BOLTS = 3

struct
{
	float[2][TRIPLE_THREAT_MAX_BOLTS] boltOffsets = [
		[0.2, 0.0],
		[0.2, 1.5], // right
		[0.2, -1.5], // left
	]
	float[TRIPLE_THREAT_MAX_BOLTS] boltSpeedOffsets = [
		1.0,
		1.1, // right
		0.9, // left
	]
} file


function HavocTripleThreat_Init()
{
	RegisterSignal( "ProxMineTrigger" )
	PrecacheWeapon("mp_titanweapon_havoc_triplethreat")
	PrecacheParticleSystem( FX_MINE_TRAIL )
	PrecacheParticleSystem( FX_MINE_LIGHT )
	PrecacheParticleSystem( FX_MINE_GLOW )
	PrecacheParticleSystem( FX_TRIPLE_IGNITION )
	PrecacheParticleSystem( FX_TRIPLE_IGNITION_BURN )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_havoc_triplethreat, TripleThreatOnDamage )
	#endif
}

var function OnWeaponPrimaryAttack_titanweapon_triple_threat_havoc( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	float zoomFrac = owner.GetZoomFrac()
	if ( zoomFrac < 1 && zoomFrac > 0)
		return 0
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	return FireTriple_Threat (weapon, attackParams, true)
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_triple_threat_havoc( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	return FireTriple_Threat (weapon, attackParams, false)
}
#endif

void function OnProjectileCollision_titanweapon_triple_threat_havoc( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	if( !IsValid( hitEnt ) )
		return

	if( "impactFuse" in projectile.s && projectile.s.impactFuse == true )
		projectile.GrenadeExplode( Vector( 0,0,0 ) )

	if( !IsValid( projectile ) )
		return


	#if SERVER
	array<string> mods = projectile.ProjectileGetMods()
	if (projectile.proj.projectileBounceCount == 0 && mods.contains( "pas_long_fuse" ))
	{
		thread WaitToMagnetise( projectile )
	}

	projectile.proj.projectileBounceCount++
	#endif

	if (hitEnt.GetTeam() != projectile.GetTeam() && !hitEnt.IsWorld())
	{
		local normal = Vector( 0, 0, 1 )
		if( "collisionNormal" in projectile.s )
			normal = projectile.s.collisionNormal
		projectile.GrenadeExplode( normal )
	}

	/*array<string> mods = projectile.ProjectileGetMods()
	if ( mods.contains( "proximity_detonate" ) )
	{
		#if SERVER
			thread Triple_ThreatProximityTrigger( projectile )
		#endif
	}*/
}

#if SERVER
void function WaitToMagnetise( entity projectile )
{
	projectile.EndSignal( "OnDestroy" )

	if (IsValid( projectile )) //not entirely sure why this is necessary
	{
		entity fx = PlayLoopFXOnEntity( FX_MINE_GLOW, projectile )
		fx.SetStopType( "destroyImmediately" )

		wait MAGNETISE_DELAY

		projectile.InitMagnetic( 1000.0, "Explo_MGL_MagneticAttract" )

		OnThreadEnd(
		function() : ( fx )
		{
			if ( IsValid(fx) )
				fx.Destroy()
		}
		)
	}
	WaitForever()
}
#endif

bool function OnWeaponChargeBegin_titanweapon_triple_threat_havoc( entity weapon )
{
	weapon.EmitWeaponSound("anim_s2s_draconis_viper_kills_bt")

	#if CLIENT
		if ( !IsFirstTimePredicted() )
			return true
	#endif

	return true
}

void function OnWeaponChargeEnd_titanweapon_triple_threat_havoc( entity weapon )
{
	weapon.StopWeaponSound("anim_s2s_draconis_viper_kills_bt")
	#if CLIENT
		if ( !IsFirstTimePredicted() )
			return
	#endif
}

#if SERVER
function Triple_ThreatProximityTrigger( entity nade )
{
	//Hack, shouldn't be necessary with the IsValid check in OnProjectileCollision.
	if( !IsValid( nade ) )
		return

	nade.EndSignal( "OnDestroy" )
	EmitSoundOnEntity( nade, "Wpn_TripleThreat_Grenade_MineAttach" )

	wait TRIPLE_THREAT_MINE_FIELD_ACTIVATION_TIME

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
				nade.Signal( "ProxMineTrigger" )
				return
			}
		}
		WaitFrame()
	}
}
#endif // SERVER

function FireTriple_Threat( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	entity bossPlayer = weaponOwner
//	bool hasRollingRoundsMod = weapon.HasMod( "rolling_rounds" )

	if ( weaponOwner.IsNPC() )
		bossPlayer = weaponOwner.GetTitanSoul().GetBossPlayer()

	bool inADS = weapon.IsWeaponInAds()
	vector attackAngles = VectorToAngles( attackParams.dir )
	vector baseUpVec = AnglesToUp( attackAngles )
	vector baseRightVec = AnglesToRight( attackAngles )

	if ( shouldCreateProjectile )
	{
		int numShots = weapon.GetProjectilesPerShot()
		float velocity = TRIPLE_THREAT_LAUNCH_VELOCITY * 1.2
		float angleAdjustment = 1.5

		if (weapon.HasMod("pas_pressurised_chamber"))
			angleAdjustment *= (0.8 - (weapon.GetWeaponChargeFraction() / 2))

		for ( int i = 0; i < numShots; i++ )
		{
			vector upVec = baseUpVec * file.boltOffsets[i][0] * 0.05
			vector rightVec = baseRightVec * file.boltOffsets[i][1] * angleAdjustment * 0.05

			if ( inADS )
			{
				// Instead of swapping for horizontal spread, add it to preserve the y-axis velocity the shots normally have
				upVec = baseUpVec * (file.boltOffsets[i][0] + file.boltOffsets[i][1] * angleAdjustment) * 0.05
				rightVec = Vector(0, 0, 0)
			}

			vector attackVec = attackParams.dir + rightVec + upVec

			if (weapon.HasMod("pas_pressurised_chamber"))
				attackVec *= (1 + (weapon.GetWeaponChargeFraction() / 3))

			if ( inADS )
				attackVec *= file.boltSpeedOffsets[i]

			float fuseTime
			if(weapon.HasMod("pas_long_fuse"))
				fuseTime = RandomFloatRange( MIN_FUSE_TIME_KIT, MAX_FUSE_TIME_KIT )
			else
				fuseTime = RandomFloatRange( MIN_FUSE_TIME, MAX_FUSE_TIME )

			int damageType = damageTypes.explosive

			vector angularVelocity = Vector( RandomFloatRange( -velocity, velocity ), 100, 0 )

			FireTriple_ThreatGrenade( weapon, attackParams.pos, attackVec, angularVelocity, playerFired, fuseTime, damageType )
		}
	}

	return 3
}

function FireTriple_ThreatGrenade( entity weapon, origin, fwd, velocity, playerFired, float fuseTime, damageType = null )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	if ( damageType == null )
		damageType = damageTypes.explosive

	entity nade = weapon.FireWeaponGrenade( origin, fwd, velocity, 0, damageType, damageType, playerFired, true, true )
	if ( nade )
	{
		nade.kv.CollideWithOwner = false

		EmitSoundOnEntity( nade, "Weapon_GibberPistol_Grenade_Emitter" )
		Grenade_Init( nade, weapon )
		#if SERVER
			nade.SetOwner( weaponOwner )
			thread EnableCollision( nade )
			thread AirPop( nade, fuseTime )
			thread TrapExplodeOnDamage( nade, 50, 0.0, 0.1 )
			thread PlayGlowEffectDelayed( FX_MINE_LIGHT, nade, 0.3 )
		#else
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif

		if (weapon.HasMod("proximity_detonate") )
		{
			#if SERVER
				thread Triple_ThreatProximityTrigger( nade )
			#endif
		}

		return nade
	}
}

#if SERVER
function PlayGlowEffectDelayed( asset particle, entity projectile, float delay = 0 )
{
	projectile.EndSignal("OnDestroy")

	wait delay
	entity fx = PlayLoopFXOnEntity( particle, projectile )
	fx.SetStopType( "destroyImmediately" )

	WaitForever()

	OnThreadEnd(
		function() : ( fx )
		{
			if ( IsValid(fx) )
				fx.Destroy()
		}
	)
}
#endif

function EnableCollision( entity grenade )
{
	grenade.EndSignal("OnDestroy")

	wait 1.0
	grenade.kv.CollideWithOwner = true
}

function AirPop( entity grenade, float fuseTime )
{
	grenade.EndSignal( "OnDestroy" )

	float popDelay = RandomFloatRange( 0.2, 0.3 )

	string waitSignal = "Planted" // Signal triggered when mine sticks to something
	local waitResult = WaitSignalTimeout( grenade, (fuseTime - (popDelay + 0.2)), waitSignal )

	// Only enter here if the mine stuck to something
	if ( waitResult != null && waitResult.signal == waitSignal )
	{
		waitSignal = "ProxMineTrigger"
		waitResult = WaitSignalTimeout( grenade, (fuseTime - (popDelay + 0.2)), waitSignal )

		// Mine was triggered via proximity
		if ( waitResult != null && waitResult.signal == waitSignal )
			EmitSoundOnEntity( grenade, "NPE_Missile_Alarm") // TEMP - Replace with a real sound
	}

	asset effect = FX_TRIPLE_IGNITION
//	if( "hasBurnMod" in grenade.s && grenade.s.hasBurnMod )
//		effect = FX_TRIPLE_IGNITION_BURN

	int fxId = GetParticleSystemIndex( effect )
	StartParticleEffectOnEntity( grenade, fxId, FX_PATTACH_ABSORIGIN_FOLLOW, -1 )

	EmitSoundOnEntity( grenade, "Triple_Threat_Grenade_Charge" )

	float popSpeed = RandomFloatRange( 40.0, 64.0 )
	vector popVelocity = Vector ( 0, 0, popSpeed )
	vector normal = Vector( 0, 0, 1 )
	if( "becomeProxMine" in grenade.s && grenade.s.becomeProxMine == true )
	{
		//grenade.ClearParent()
		if( "collisionNormal" in grenade.s )
		{
			normal = expect vector( grenade.s.collisionNormal )
			popVelocity = expect vector( grenade.s.collisionNormal ) * popSpeed
		}
	}

	vector newPosition = grenade.GetOrigin() + popVelocity
	grenade.SetVelocity( GetVelocityForDestOverTime( grenade.GetOrigin(), newPosition, popDelay ) )

	wait popDelay
	Triple_Threat_Explode( grenade )
}

function Triple_Threat_Explode( entity grenade )
{
	vector normal = Vector( 0, 0, 1 )
	if( "collisionNormal" in grenade.s )
		normal = expect vector( grenade.s.collisionNormal )

	grenade.GrenadeExplode( normal )
}

#if SERVER
void function TripleThreatOnDamage( entity ent, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if( ent == attacker )
		DamageInfo_ScaleDamage( damageInfo, 0.5 )
}
#endif
