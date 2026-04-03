untyped
global function MpTitanweaponShockWave_Init
global function OnWeaponPrimaryAttack_titanweapon_shockwave

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_shockwave
#endif
global function OnProjectileCollision_weapon_shockwave

const asset SHOCKWAVE_EFFECT = $"exp_shockwave_main"

const float SHOCKWAVE_LOW_DAMAGE_WAVE = 3
const float SHOCKWAVE_HIGH_DAMAGE_WAVE = 9

const float LOW_DAMAGE_SCALAR = 0.6
const float HIGH_DAMAGE_SCALAR = 1.0

const float SHAKE_DURATION = 1.0
const float SHAKE_AMPLITUDE = 180

void function MpTitanweaponShockWave_Init()
{
 	PrecacheParticleSystem(SHOCKWAVE_EFFECT)

	PrecacheWeapon( "mp_titanweapon_shockwave" )
}

	#if SERVER
		//AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_shockwave, ShockWaveOnDamage )
	#endif

void function OnProjectileCollision_weapon_shockwave( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{

}

var function OnWeaponPrimaryAttack_titanweapon_shockwave( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	const float FUSE_TIME = 99.0
	entity projectile = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, < 0,0,0 >, FUSE_TIME, damageTypes.projectileImpact, damageTypes.explosive, shouldPredict, true, true )
	if ( IsValid( projectile ) )
	{
		entity owner = weapon.GetWeaponOwner()

		#if SERVER
		//	PlayFX( FLIGHT_CORE_IMPACT_FX, owner.GetOrigin() )
		#endif

		if ( owner.IsPlayer() && PlayerHasPassive( owner, ePassives.PAS_SHIFT_CORE ) )
		{
			#if SERVER
				projectile.proj.isChargedShot = true
			#endif
		}

		if ( owner.IsPlayer() )
			PlayerUsedOffhand( owner, weapon )

		#if SERVER
			thread BeginEmpWave( projectile, attackParams )
		#endif
	}

	#if CLIENT
		thread ClientScreenShakeDelayed( 10.0, 7.0, 1.0, Vector( 0.0, 0.0, 0.0 ), 0.2 )
	#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}

#if CLIENT
void function ClientScreenShakeDelayed( float amplitude, float frequency, float duration, vector direction, float delay = 0.0 )
{
	wait delay
	ClientScreenShake( amplitude, frequency, duration, direction )
}
#endif

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_shockwave( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	const float FUSE_TIME = 99.0
	entity projectile = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, < 0,0,0 >, FUSE_TIME, damageTypes.projectileImpact, damageTypes.explosive, false, true, true )
	if ( IsValid( projectile ) )
		thread BeginEmpWave( projectile, attackParams )

	return 1
}

void function BeginEmpWave( entity projectile, WeaponPrimaryAttackParams attackParams )
{
	projectile.EndSignal("OnDestroy")
	projectile.SetAbsOrigin( projectile.GetOrigin() )
	projectile.SetAbsAngles( projectile.GetAngles() )
	projectile.SetVelocity( Vector( 0, 0, 0 ) )
	projectile.StopPhysics()
	projectile.SetTakeDamageType( DAMAGE_NO )
	projectile.Hide()
	projectile.NotSolid()
	projectile.e.onlyDamageEntitiesOnce = true
	EmitSoundOnEntity( projectile, "flamewall_start_1p" )
	waitthread WeaponAttackWaveWithDelay( projectile, 0, projectile, attackParams.pos, attackParams.dir, CreateShockWaveSegment, 0.15 )
	StopSoundOnEntity( projectile, "flamewall_start_1p" )
	projectile.Destroy()
}

bool function CreateShockWaveSegment( entity projectile, int projectileCount, entity inflictor, entity movingGeo, vector pos, vector angles, int waveCount )
{
	projectile.SetOrigin( pos )

	float  damageScalar = waveCount / float( projectile.ProjectileGetWeaponInfoFileKeyField( "wave_max_count" ) )
  	damageScalar = GraphCapped(damageScalar, (SHOCKWAVE_LOW_DAMAGE_WAVE / 10), (SHOCKWAVE_HIGH_DAMAGE_WAVE / 10), LOW_DAMAGE_SCALAR, HIGH_DAMAGE_SCALAR)

	int fxId = GetParticleSystemIndex(SHOCKWAVE_EFFECT)

  	StartParticleEffectInWorld( fxId, pos, angles )
  	print("Wave " + waveCount + " + ProjOrigin: " + projectile.GetOrigin())
  	PlayImpactFXTable( projectile.GetOrigin(), projectile.GetOwner(), "exp_shockwave_small", SF_ENVEXPLOSION_NO_DAMAGEOWNER | SF_ENVEXPLOSION_MASK_BRUSHONLY | SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT )
//  	PlayImpactFXTable( projectile.GetOrigin(), projectile.GetOwner(), "exp_shockwave_large", SF_ENVEXPLOSION_NO_DAMAGEOWNER | SF_ENVEXPLOSION_MASK_BRUSHONLY | SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT )

	int pilotDamage = int( float( projectile.GetProjectileWeaponSettingInt( eWeaponVar.damage_near_value ) ) * damageScalar )
	int titanDamage = int( float( projectile.GetProjectileWeaponSettingInt( eWeaponVar.damage_near_value_titanarmor ) ) * damageScalar )

	#if SERVER
		CreateShake( pos, SHAKE_AMPLITUDE * damageScalar, 80, SHAKE_DURATION, 600 * damageScalar )
	#endif

	RadiusDamage(
		pos,
		projectile.GetOwner(), //attacker
		inflictor, //inflictor
		pilotDamage,
		titanDamage,
		250, // inner radius
		250, // outer radius
		SF_ENVEXPLOSION_NO_DAMAGEOWNER | SF_ENVEXPLOSION_MASK_BRUSHONLY | SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,
		0, // distanceFromAttacker
		5000, // explosionForce
		DF_ELECTRICAL | DF_STOPS_TITAN_REGEN | DF_GIB,
		eDamageSourceId.mp_titanweapon_shockwave )

	foreach( mod in projectile.ProjectileGetMods())
		if (mod == "aftershocks")
			thread CreateMicroShockWaveSegment(pos, projectile, projectile.GetOwner(), inflictor, angles, 2.0, float(projectile.GetProjectileWeaponSettingInt(eWeaponVar.damage_near_value)), float(projectile.GetProjectileWeaponSettingInt(eWeaponVar.damage_near_value_titanarmor)))

	return true
}

bool function CreateMicroShockWaveSegment(vector pos, entity projectile, entity owner, entity inflictor, vector angles, float delay, float pDamage, float tDamage)
{
	wait(delay)
  	float damageScalar = 0.6 //50% damage on Aftershocks, no ramp up, move me to the top later
	int fxId = GetParticleSystemIndex(SHOCKWAVE_EFFECT) //Change me later

  	StartParticleEffectInWorld( fxId, pos, angles )

  	PlayImpactFXTable( pos, owner, "exp_shockwave_small", SF_ENVEXPLOSION_NO_DAMAGEOWNER | SF_ENVEXPLOSION_MASK_BRUSHONLY | SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT )
//  	PlayImpactFXTable( pos, owner, "exp_shockwave_large", SF_ENVEXPLOSION_NO_DAMAGEOWNER | SF_ENVEXPLOSION_MASK_BRUSHONLY | SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT )

	int pilotDamage = int( pDamage * damageScalar )
	int titanDamage = int( pDamage * damageScalar )

	RadiusDamage(
		pos,
		owner, //attacker
		inflictor, //inflictor
		pilotDamage,
		titanDamage,
		120, // inner radius
		150, // outer radius
		SF_ENVEXPLOSION_NO_DAMAGEOWNER | SF_ENVEXPLOSION_MASK_BRUSHONLY | SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,
		0, // distanceFromAttacker
		5000, // explosionForce
		DF_ELECTRICAL | DF_STOPS_TITAN_REGEN | DF_GIB,
		eDamageSourceId.mp_titanweapon_shockwave )

	return true
}

void function WeaponAttackWaveWithDelay( entity ent, int projectileCount, entity inflictor, vector pos, vector dir, bool functionref( entity, int, entity, entity, vector, vector, int ) waveFunc, float delay = 0 )
{
  entity owner = ent.GetOwner()
	owner.EndSignal( "OnDestroy" )

	entity weapon
	entity projectile
	int maxCount
	float step
	int damageNearValueTitanArmor
	int count = 0
	array<vector> positions = []
	vector lastDownPos
	bool firstTrace = true

	dir = <dir.x, dir.y, 0.0>
	dir = Normalize( dir )
	vector angles = VectorToAngles( dir )

	if ( ent.IsProjectile() )
	{
		projectile = ent
		string chargedPrefix = ""
		if ( ent.proj.isChargedShot )
			chargedPrefix = "charge_"

		maxCount = expect int( ent.ProjectileGetWeaponInfoFileKeyField( chargedPrefix + "wave_max_count" ) )
		step = expect float( ent.ProjectileGetWeaponInfoFileKeyField( chargedPrefix + "wave_step_dist" ) )
		owner = ent.GetOwner()
		damageNearValueTitanArmor = projectile.GetProjectileWeaponSettingInt( eWeaponVar.damage_near_value_titanarmor )
	}
	else
	{
		weapon = ent
		maxCount = expect int( ent.GetWeaponInfoFileKeyField( "wave_max_count" ) )
		step = expect float( ent.GetWeaponInfoFileKeyField( "wave_step_dist" ) )
		owner = ent.GetWeaponOwner()
		damageNearValueTitanArmor = weapon.GetWeaponSettingInt( eWeaponVar.damage_near_value_titanarmor )
	}

	owner.EndSignal( "OnDestroy" )

	for ( int i = 0; i < maxCount; i++ )
	{
		vector newPos = pos + dir * step

		vector traceStart = pos
		vector traceEndUnder = newPos
		vector traceEndOver = newPos

		if ( !firstTrace )
		{
			traceStart = lastDownPos + <0.0, 0.0, 80.0 >
			traceEndUnder = <newPos.x, newPos.y, traceStart.z - 40.0 >
			traceEndOver = <newPos.x, newPos.y, traceStart.z + step * 0.57735056839> // The over height is to cover the case of a sheer surface that then continues gradually upwards (like mp_box)
		}
		firstTrace = false

		VortexBulletHit ornull vortexHit = VortexBulletHitCheck( owner, traceStart, traceEndOver )
		if ( vortexHit )
		{
			expect VortexBulletHit( vortexHit )
			entity vortexWeapon = vortexHit.vortex.GetOwnerWeapon()

			if ( vortexWeapon && vortexWeapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield" )
				VortexDrainedByImpact( vortexWeapon, weapon, projectile, null ) // drain the vortex shield
			else if ( IsVortexSphere( vortexHit.vortex ) )
				VortexSphereDrainHealthForDamage( vortexHit.vortex, damageNearValueTitanArmor )

			WaitFrame()
			continue
		}

		//DebugDrawLine( traceStart, traceEndUnder, 0, 255, 0, true, 25.0 )
		array ignoreArray = []
		if ( IsValid( inflictor ) && inflictor.GetOwner() != null )
			ignoreArray.append( inflictor.GetOwner() )

		TraceResults forwardTrace = TraceLine( traceStart, traceEndUnder, ignoreArray, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_BLOCK_WEAPONS )
		if ( forwardTrace.fraction == 1.0 )
		{
			//DebugDrawLine( forwardTrace.endPos, forwardTrace.endPos + <0.0, 0.0, -1000.0>, 255, 0, 0, true, 25.0 )
			TraceResults downTrace = TraceLine( forwardTrace.endPos, forwardTrace.endPos + <0.0, 0.0, -1000.0>, ignoreArray, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_BLOCK_WEAPONS )
			if ( downTrace.fraction == 1.0 )
				break

			entity movingGeo = null
			if ( downTrace.hitEnt && downTrace.hitEnt.HasPusherRootParent() && !downTrace.hitEnt.IsMarkedForDeletion() )
				movingGeo = downTrace.hitEnt

			if ( !waveFunc( ent, projectileCount, inflictor, movingGeo, downTrace.endPos, angles, i ) )
				return

			lastDownPos = downTrace.endPos
			pos = forwardTrace.endPos

      if(delay <= 0)
  		  WaitFrame()
      else
        wait delay
			continue
		}
		else
		{
			if ( IsValid( forwardTrace.hitEnt ) && (StatusEffect_Get( forwardTrace.hitEnt, eStatusEffect.pass_through_amps_weapon ) > 0) && !CheckPassThroughDir( forwardTrace.hitEnt, forwardTrace.surfaceNormal, forwardTrace.endPos ) )
				break;
		}

		TraceResults upwardTrace = TraceLine( traceStart, traceEndOver, ignoreArray, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_BLOCK_WEAPONS )
		//DebugDrawLine( traceStart, traceEndOver, 0, 0, 255, true, 25.0 )
		if ( upwardTrace.fraction < 1.0 )
		{
			if ( IsValid( upwardTrace.hitEnt ) )
			{
				if ( upwardTrace.hitEnt.IsWorld() || upwardTrace.hitEnt.IsPlayer() || upwardTrace.hitEnt.IsNPC() )
					break
			}
		}
		else
		{
			TraceResults downTrace = TraceLine( upwardTrace.endPos, upwardTrace.endPos + <0.0, 0.0, -1000.0>, ignoreArray, TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_BLOCK_WEAPONS )
			if ( downTrace.fraction == 1.0 )
				break

			entity movingGeo = null
			if ( downTrace.hitEnt && downTrace.hitEnt.HasPusherRootParent() && !downTrace.hitEnt.IsMarkedForDeletion() )
				movingGeo = downTrace.hitEnt

			if ( !waveFunc( ent, projectileCount, inflictor, movingGeo, downTrace.endPos, angles, i ) )
				return

			lastDownPos = downTrace.endPos
			pos = forwardTrace.endPos
		}

    WaitFrame()
	}
}
#endif

void function ShockWaveOnDamage( entity ent, var damageInfo )
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

    const ARC_TITAN_EMP_DURATION			= 1.0
    const ARC_TITAN_EMP_FADEOUT_DURATION	= 0.35


    StatusEffect_AddTimed( entToSlow, eStatusEffect.move_slow, 0.5, 1.5, 1.0 )
    StatusEffect_AddTimed( entToSlow, eStatusEffect.dodge_speed_slow, 0.5, 1.5, 1.0 )
    StatusEffect_AddTimed( ent, eStatusEffect.emp, 1.0, ARC_TITAN_EMP_DURATION, ARC_TITAN_EMP_FADEOUT_DURATION )
  }
}
