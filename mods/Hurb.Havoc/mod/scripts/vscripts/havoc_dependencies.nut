global function Havoc_CheckDependencies

struct
{
    string currentMod           = "Hurb.Havoc"
    string currentDependency    = "Peepee.TitanFramework"
    string currentURL           = "https://northstar.thunderstore.io/package/The_Peepeepoopoo_man/Titanframework/"
} file

void function Havoc_CheckDependencies()
{
    #if HAVOC_HAS_TITANFRAMEWORK

    #elseif UI
        Havoc_CreateDependencyDialog()
    #endif
}

void function Havoc_CreateDependencyDialog()
{
    DialogData dialogData
    dialogData.forceChoice = true
    dialogData.header = Localize("#MISSING_DEPENDENCY_HEADER")
    dialogData.image = $"ui/menu/common/dialog_error"

    array<ModInfo> mods = NSGetModInformation( file.currentDependency )
    // mod is installed but disabled
    if ( mods.len() > 0 )
    {
        dialogData.message = Localize( "#MISSING_DEPENDENCY_BODY_DISABLED", file.currentMod, file.currentDependency )
        AddDialogButton( dialogData, Localize("#ENABLE_MOD", file.currentDependency ), Havoc_EnableMod )
    }
    else
    {
        dialogData.message = Localize( "#MISSING_DEPENDENCY_BODY_INSTALL", file.currentMod, file.currentDependency, file.currentURL )
        AddDialogButton( dialogData, "#OPEN_THUNDERSTORE", Havoc_InstallMod )
    }

    AddDialogButton( dialogData, Localize("#DISABLE_MOD", file.currentMod), Havoc_DisableMod )
    AddDialogFooter( dialogData, "#A_BUTTON_SELECT" )
	OpenDialog( dialogData )
}

void function Havoc_EnableMod()
{
    NSSetModEnabled( file.currentDependency, NSGetModInformation(file.currentDependency)[0].version, true )
    ReloadMods()
}

void function Havoc_InstallMod()
{
    LaunchExternalWebBrowser(file.currentURL, WEBBROWSER_FLAG_FORCEEXTERNAL)
    ReloadMods()
}

void function Havoc_DisableMod()
{
    array<ModInfo> mods = NSGetModInformation( file.currentMod )
    foreach ( ModInfo mod in mods ){ NSSetModEnabled( file.currentMod, mod.version, false ) }
    ReloadMods()
}

/*void function Havoc_CheckDuplicateVersions()
{
    array<ModInfo> mods = NSGetModInformation( file.currentMod )

    if ( mods.len() == 1 )
    {
        Havoc_CreateDependencyDialog()
        return
    }

    DialogData dialogData
    dialogData.forceChoice = true
    dialogData.header = Localize("#SELECT_DEPENDENCY_HEADER", file.currentMod)
    dialogData.image = $"ui/menu/common/dialog_error"

    dialogData.message = Localize("#SELECT_DEPENDENCY_BODY", file.currentMod)

    foreach ( ModInfo mod in mods )
    {
        void functionref() enableFunc = void function() : ( mod )
        {
            NSSetModEnabled( file.currentMod, mod.version, true )
            Havoc_CreateDependencyDialog()
        }
        NSSetModEnabled( file.currentMod, mod.version, false )
        AddDialogButton(dialogData, Localize("#ENABLE_MOD_VERSION", file.currentMod, mod.version), enableFunc )
    }
    AddDialogFooter( dialogData, "#A_BUTTON_SELECT" )
    OpenDialog( dialogData )
}*/
