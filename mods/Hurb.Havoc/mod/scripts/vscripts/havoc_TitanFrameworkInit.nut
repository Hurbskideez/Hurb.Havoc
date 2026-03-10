global function HavocUIInit
void function HavocUIInit()
{
	#if HAVOC_HAS_TITANFRAMEWORK
	//========================================//-NAMES AND STATS-//========================================//
		ModdedTitanData Havoc
		Havoc.Name = "#DEFAULT_TITAN_HAVOC"
		Havoc.icon = $"havoc/menu/havoc_icon_medium"
		Havoc.Description = "#MP_TITAN_LOADOUT_DESC_HAVOC"
		Havoc.BaseSetFile = "titan_ogre_minigun"
		Havoc.BaseName = "legion"
		Havoc.startsAsPrime = true
		Havoc.passiveDisplayNameOverride = "#TITAN_HAVOC_PASSIVE_TITLE"
		Havoc.difficulty = 1
		Havoc.speedStat = 1
		Havoc.damageStat = 2
		Havoc.healthStat = 3
		Havoc.titanHints = ["#DEATH_HINT_HAVOC_001",
		"#DEATH_HINT_HAVOC_002",
		"#DEATH_HINT_HAVOC_003",
		"#DEATH_HINT_HAVOC_004",
		"#DEATH_HINT_HAVOC_005",
		"#DEATH_HINT_HAVOC_006",
		"#DEATH_HINT_HAVOC_007" ]

		//========================================//-WEAPONS-//========================================//
		ModdedTitanWeaponAbilityData TripleThreat
		TripleThreat.custom = true
		TripleThreat.displayName = "#WPN_HAVOC_TRIPLE_THREAT"
		TripleThreat.weaponName = "mp_titanweapon_havoc_triplethreat"
		TripleThreat.description = "#WPN_HAVOC_TRIPLE_THREAT_LONGDESC"
		TripleThreat.image = $"havoc/hud/titan_weapon_triplethreat"
		Havoc.Primary = TripleThreat

		ModdedTitanWeaponAbilityData Shockwave
		Shockwave.custom = true
		Shockwave.displayName = "#WPN_TITAN_SHOCKWAVE"
		Shockwave.weaponName = "mp_titanweapon_shockwave"
		Shockwave.description = "#WPN_TITAN_SHOCKWAVE_LONGDESC"
		Shockwave.image = $"havoc/menu/shockwave_menu"
		Havoc.Right = Shockwave

		ModdedTitanWeaponAbilityData BerserkCore
		BerserkCore.custom = true
		BerserkCore.weaponName = "mp_titancore_berserk_core"
		BerserkCore.displayName = "#TITANCORE_BERSERK"
		BerserkCore.description = "#TITANCORE_BERSERK_DESC"
		BerserkCore.image = $"rui/titan_loadout/core/titan_core_burst_core"
		Havoc.Core = BerserkCore

		ModdedTitanWeaponAbilityData Blastshield
		Blastshield.custom = true
		Blastshield.displayName = "#WPN_TITAN_BLAST_SHIELD"
		Blastshield.weaponName = "mp_titanweapon_blast_shield"
		Blastshield.description = "#WPN_TITAN_BLAST_SHIELD_LONGDESC"
		Blastshield.image = $"havoc/hud/polarize_wall"
		Havoc.Left = Blastshield

		ModdedTitanWeaponAbilityData ArcCharge
		ArcCharge.custom = true
		ArcCharge.displayName = "#WPN_TITAN_ARC_CHARGE"
		ArcCharge.weaponName = "mp_titanweapon_arc_charge"
		ArcCharge.description = "#WPN_TITAN_ARC_CHARGE_DESC"
		ArcCharge.image = $"havoc/menu/arc_charge_menu"
		Havoc.Mid = ArcCharge

		Havoc.Melee = "melee_titan_punch_havoc"

		//========================================//-KITS-//========================================//
		ModdedPassiveData Empty
		Empty.Name = "None"
		Empty.description = "No Kit."
		//PressurisedChamber.image = $""
		Empty.customIcon = true
		Havoc.passive2Array.append(Empty)

		ModdedPassiveData StuffedCylinder
		StuffedCylinder.Name = "#GEAR_HAVOC_AMMO"
		StuffedCylinder.description = "#GEAR_HAVOC_AMMO_DESC"
		//PressurisedChamber.image = $""
		StuffedCylinder.customIcon = true
		Havoc.passive2Array.append(StuffedCylinder)

		ModdedPassiveData PressurisedChamber
		PressurisedChamber.Name = "#GEAR_HAVOC_HYDRAULIC"
		PressurisedChamber.description = "#GEAR_HAVOC_HYDRAULIC_DESC"
		//PressurisedChamber.image = $""
		PressurisedChamber.customIcon = true
		Havoc.passive2Array.append(PressurisedChamber)

		CreateModdedTitanSimple(Havoc)
	#endif
}
