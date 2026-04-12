// I have to copy all this code just to make Vortex a different color
untyped

global function BlastShield_EnableVortexSphere
global function GetBlastShieldCurrentColor

const BLAST_SHIELD_COLOR_CHARGE_FULL		= <156, 116, 51>	// white cyan
const BLAST_SHIELD_COLOR_CHARGE_MED		= <156, 116, 51>	// orange
const BLAST_SHIELD_COLOR_CHARGE_EMPTY		= <155, 160, 110>	// red

//new colours for Wip colour thing
//180, 160, 120 off-white for higher end of flash
//125, 90, 10 brighter yellow for lower end of flash
//68, 48, 4 default shield colour while charging

const BLAST_SHIELD_COLOR_CROSSOVERFRAC_FULL2MED	= 0.9  // from zero to this fraction, fade between full and medium charge colors
const BLAST_SHIELD_COLOR_CROSSOVERFRAC_MED2EMPTY	= 1.0  // from "full2med" to this fraction, fade between medium and empty charge colors

function BlastShield_EnableVortexSphere( entity vortexWeapon )
{
	string tagname = GetVortexTagName( vortexWeapon )
	entity weaponOwner = vortexWeapon.GetWeaponOwner()
	local hasBurnMod = vortexWeapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod )

	#if SERVER
		entity vortexSphere = vortexWeapon.GetWeaponUtilityEntity()
		Assert( vortexSphere )
		vortexSphere.FireNow( "Enable" )

		thread SetPlayerUsingVortex( weaponOwner, vortexWeapon )

		Vortex_CreateAbsorbFX_ControlPoints( vortexWeapon )

		// world (3P) version of the vortex sphere FX
		vortexSphere.s.worldFX <- CreateEntity( "info_particle_system" )

		if ( hasBurnMod )
		{
			if ( "fxChargingControlPointBurn" in vortexWeapon.s )
				vortexSphere.s.worldFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxChargingControlPointBurn ) )
		}
		else
		{
			if ( "fxChargingControlPoint" in vortexWeapon.s )
				vortexSphere.s.worldFX.SetValueForEffectNameKey( expect asset( vortexWeapon.s.fxChargingControlPoint ) )
		}

		vortexSphere.s.worldFX.kv.start_active = 1
		vortexSphere.s.worldFX.SetOwner( weaponOwner )
		vortexSphere.s.worldFX.SetParent( vortexWeapon, tagname )
		vortexSphere.s.worldFX.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY) // not owner only
		vortexSphere.s.worldFX.kv.cpoint1 = vortexWeapon.s.vortexSphereColorCP.GetTargetName()
		vortexSphere.s.worldFX.SetStopType( "destroyImmediately" )

		DispatchSpawn( vortexSphere.s.worldFX )
	#endif

	SetVortexAmmo( vortexWeapon, 0 )

	#if CLIENT
		if ( IsLocalViewPlayer( weaponOwner ) )
	{
		local fxAlias = null

		if ( hasBurnMod )
		{
			if ( "fxChargingFPControlPointBurn" in vortexWeapon.s )
				fxAlias = vortexWeapon.s.fxChargingFPControlPointBurn
		}
		else
		{
			if ( "fxChargingFPControlPoint" in vortexWeapon.s )
				fxAlias = vortexWeapon.s.fxChargingFPControlPoint
		}

		if ( fxAlias )
		{
			int sphereClientFXHandle = vortexWeapon.PlayWeaponEffectReturnViewEffectHandle( fxAlias, $"", tagname )
			thread VortexSphereColorUpdate( vortexWeapon, sphereClientFXHandle )
		}
	}
	#elseif  SERVER
		asset fxAlias = $""

		if ( hasBurnMod )
		{
			if ( "fxChargingFPControlPointReplayBurn" in vortexWeapon.s )
				fxAlias = expect asset( vortexWeapon.s.fxChargingFPControlPointReplayBurn )
		}
		else
		{
			if ( "fxChargingFPControlPointReplay" in vortexWeapon.s )
				fxAlias = expect asset( vortexWeapon.s.fxChargingFPControlPointReplay )
		}

		if ( fxAlias != $"" )
			vortexWeapon.PlayWeaponEffect( fxAlias, $"", tagname )

		thread VortexSphereColorUpdate( vortexWeapon )
	#endif
}

// sets the RGB color value for the vortex sphere FX based on current charge fraction
function VortexSphereColorUpdate( entity weapon, sphereClientFXHandle = null )
{
	weapon.EndSignal( "VortexStopping" )

	#if CLIENT
		Assert( sphereClientFXHandle != null )
	#endif
	entity weaponOwner = weapon.GetWeaponOwner()
	while( IsValid( weapon ) && IsValid( weaponOwner ) )
	{
		vector colorVec = GetBlastShieldCurrentColor(BlastShield_GetCharge(weapon))

		// update the world entity that is linked to the world FX playing on the server
		#if SERVER
			weapon.s.vortexSphereColorCP.SetOrigin( colorVec )
		#else
			// handles the server killing the vortex sphere without the client knowing right away,
			//  for example if an explosive goes off and we short circuit the charge timer
			if ( !EffectDoesExist( sphereClientFXHandle ) )
				break

			EffectSetControlPointVector( sphereClientFXHandle, 1, colorVec )
		#endif

		WaitFrame()
	}
}

vector function GetBlastShieldCurrentColor( float fraction )
{
	return GetTriLerpColor( fraction, BLAST_SHIELD_COLOR_CHARGE_FULL, BLAST_SHIELD_COLOR_CHARGE_MED, BLAST_SHIELD_COLOR_CHARGE_EMPTY )
}

vector function GetTriLerpColor( float fraction, vector color1, vector color2, vector color3 )
{
	float crossover1 = BLAST_SHIELD_COLOR_CROSSOVERFRAC_FULL2MED  // from zero to this fraction, fade between color1 and color2
	float crossover2 = BLAST_SHIELD_COLOR_CROSSOVERFRAC_MED2EMPTY  // from crossover1 to this fraction, fade between color2 and color3

	float r, g, b

	// 0 = full charge, 1 = no charge remaining
	if ( fraction < crossover1 )
	{
		r = Graph( fraction, 0, crossover1, color1.x, color2.x )
		g = Graph( fraction, 0, crossover1, color1.y, color2.y )
		b = Graph( fraction, 0, crossover1, color1.z, color2.z )
		return <r, g, b>
	}
	else if ( fraction < crossover2 )
	{
		r = Graph( fraction, crossover1, crossover2, color2.x, color3.x )
		g = Graph( fraction, crossover1, crossover2, color2.y, color3.y )
		b = Graph( fraction, crossover1, crossover2, color2.z, color3.z )
		return <r, g, b>
	}
	else
	{
		// for the last bit of overload timer, keep it max danger color
		r = color3.x
		g = color3.y
		b = color3.z
		return <r, g, b>
	}

	unreachable
}

function SetVortexAmmo( entity vortexWeapon, count )
{
	entity owner = vortexWeapon.GetWeaponOwner()
	if ( !IsValid_ThisFrame( owner ) )
		return
	#if CLIENT
		if ( !IsLocalViewPlayer( owner ) )
		return
	#endif

	vortexWeapon.SetWeaponPrimaryAmmoCount( count )
}

string function GetVortexTagName( entity weapon )
{
	if ( "vortexTagName" in weapon.s )
		return expect string( weapon.s.vortexTagName )

	return "vortex_center"
}

function SetPlayerUsingVortex( entity weaponOwner, entity vortexWeapon )
{
	weaponOwner.EndSignal( "OnDeath" )

	weaponOwner.s.isVortexing <- true

	vortexWeapon.WaitSignal( "VortexStopping" )

	OnThreadEnd
	(
		function() : ( weaponOwner )
		{
			if ( IsValid_ThisFrame( weaponOwner ) && "isVortexing" in weaponOwner.s )
			{
				delete weaponOwner.s.isVortexing
			}
		}
	)
}

#if SERVER
function Vortex_CreateAbsorbFX_ControlPoints( entity vortexWeapon )
{
	entity player = vortexWeapon.GetWeaponOwner()
	Assert( player )

	// vortex swirling incoming rounds FX location control point
	if ( !( "vortexBulletEffectCP" in vortexWeapon.s ) )
		vortexWeapon.s.vortexBulletEffectCP <- null
	vortexWeapon.s.vortexBulletEffectCP = CreateEntity( "info_placement_helper" )
	SetTargetName( expect entity( vortexWeapon.s.vortexBulletEffectCP ), UniqueString( "vortexBulletEffectCP" ) )
	vortexWeapon.s.vortexBulletEffectCP.kv.start_active = 1

	DispatchSpawn( vortexWeapon.s.vortexBulletEffectCP )

	vector offset = GetBulletCollectionOffset( vortexWeapon )
	vector origin = player.OffsetPositionFromView( player.EyePosition(), offset )

	vortexWeapon.s.vortexBulletEffectCP.SetOrigin( origin )
	vortexWeapon.s.vortexBulletEffectCP.SetParent( player )

	// vortex sphere color control point
	if ( !( "vortexSphereColorCP" in vortexWeapon.s ) )
		vortexWeapon.s.vortexSphereColorCP <- null
	vortexWeapon.s.vortexSphereColorCP = CreateEntity( "info_placement_helper" )
	SetTargetName( expect entity( vortexWeapon.s.vortexSphereColorCP ), UniqueString( "vortexSphereColorCP" ) )
	vortexWeapon.s.vortexSphereColorCP.kv.start_active = 1

	DispatchSpawn( vortexWeapon.s.vortexSphereColorCP )
}

vector function GetBulletCollectionOffset( entity weapon )
{
	if ( "bulletCollectionOffset" in weapon.s )
		return expect vector( weapon.s.bulletCollectionOffset )

	entity owner = weapon.GetWeaponOwner()
	if ( owner.IsTitan() )
		return Vector( 300.0, -90.0, -70.0 )
	else
		return Vector( 80.0, 17.0, -11.0 )

	unreachable
}
#endif
