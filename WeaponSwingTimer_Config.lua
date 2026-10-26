local addon_name, addon_data = ...

addon_data.config = {}

-- The options window is built in WeaponSwingTimer_Options.lua
addon_data.config.InitializeVisuals = function()
    addon_data.options.Register()
end

addon_data.config.SetLocked = function(locked)
    locked = locked and true or false
    character_player_settings.is_locked = locked
    character_target_settings.is_locked = locked
    character_hunter_settings.is_locked = locked
    character_castbar_settings.is_locked = locked
    addon_data.player.frame:EnableMouse(not locked)
    addon_data.target.frame:EnableMouse(not locked)
    addon_data.hunter.frame:EnableMouse(not locked)
    addon_data.castbar.frame:EnableMouse(not locked)
    addon_data.core.UpdateAllVisualsOnSettingsChange()
end
