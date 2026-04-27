global function HavocUIInit
void function HavocUIInit()
{
	#if HAVOC_HAS_TITANFRAMEWORK
	//========================================//-NAMES AND STATS-//========================================//
		ModdedTitanData Havoc
		Havoc.Name = "#DEFAULT_TITAN_HAVOC"
		Havoc.icon = $"havoc/menus/loadout_icons/titans/havoc_icon"
		Havoc.Description = "#MP_TITAN_LOADOUT_DESC_HAVOC"
		Havoc.BaseSetFile = "titan_ogre_legion_prime"
		Havoc.BaseName = "legion"
		Havoc.startsAsPrime = true
		Havoc.altChassisType = frameworkAltChassisMethod.NONE
		Havoc.passiveDisplayNameOverride = "#TITAN_HAVOC_PASSIVE_TITLE"
		Havoc.titanReadyMessageOverride = "#HUD_HAVOC_READY"
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
		TripleThreat.image = $"havoc/menus/loadout_icons/titan_weapon/titan_weapon_triplethreat"
		Havoc.Primary = TripleThreat

		ModdedTitanWeaponAbilityData Shockwave
		Shockwave.custom = true
		Shockwave.displayName = "#WPN_TITAN_SHOCKWAVE"
		Shockwave.weaponName = "mp_titanweapon_shockwave"
		Shockwave.description = "#WPN_TITAN_SHOCKWAVE_LONGDESC"
		Shockwave.image = $"havoc/titan_loadout/ordnance/shockwave_menu"
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
		Blastshield.image = $"havoc/titan_loadout/defensive/blast_shield_menu"
		Havoc.Left = Blastshield

		ModdedTitanWeaponAbilityData ArcCharge
		ArcCharge.custom = true
		ArcCharge.displayName = "#WPN_TITAN_ARC_CHARGE"
		ArcCharge.weaponName = "mp_titanweapon_arc_charge"
		ArcCharge.description = "#WPN_TITAN_ARC_CHARGE_DESC"
		ArcCharge.image = $"havoc/titan_loadout/tactical/titan_tactical_arc_charge_menu"
		Havoc.Mid = ArcCharge

		Havoc.Melee = "melee_titan_punch_havoc"

		//========================================//-KITS-//========================================//
		ModdedPassiveData Empty
		Empty.Name = "None"
		Empty.description = "No Kit."
		//PressurisedChamber.image = $""
		Empty.customIcon = true
		Havoc.passive2Array.append(Empty)

		ModdedPassiveData BiteTheBullet
		BiteTheBullet.Name = "#GEAR_HAVOC_TRIPLETHREAT"
		BiteTheBullet.description = "#GEAR_HAVOC_TRIPLETHREAT_DESC"
		BiteTheBullet.image = $"havoc/titan_loadout/passive/havoc_bite_the_bullet"
		BiteTheBullet.customIcon = true
		Havoc.passive2Array.append(BiteTheBullet)

		ModdedPassiveData EnergyDenseCells
		EnergyDenseCells.Name = "#GEAR_HAVOC_ARCCHARGE"
		EnergyDenseCells.description = "#GEAR_HAVOC_ARCCHARGE_DESC"
		EnergyDenseCells.image = $"havoc/titan_loadout/passive/havoc_energy_dense_cells"
		EnergyDenseCells.customIcon = true
		Havoc.passive2Array.append(EnergyDenseCells)

		ModdedPassiveData HydraulicLauncher
		HydraulicLauncher.Name = "#GEAR_HAVOC_HYDRAULIC"
		HydraulicLauncher.description = "#GEAR_HAVOC_HYDRAULIC_DESC"
		HydraulicLauncher.image = $"havoc/titan_loadout/passive/havoc_hydraulic_launcher"
		HydraulicLauncher.customIcon = true
		Havoc.passive2Array.append(HydraulicLauncher)

		ModdedPassiveData ExhaustRecycler
		ExhaustRecycler.Name = "#GEAR_HAVOC_BLASTSHIELD"
		ExhaustRecycler.description = "#GEAR_HAVOC_BLASTSHIELD_DESC"
		ExhaustRecycler.image = $"havoc/titan_loadout/passive/havoc_exhaust_recycler"
		ExhaustRecycler.customIcon = true
		Havoc.passive2Array.append(ExhaustRecycler)

		CreateModdedTitanSimple(Havoc)
	#endif
}
