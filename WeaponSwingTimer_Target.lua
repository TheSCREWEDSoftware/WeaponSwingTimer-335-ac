local addon_name, addon_data = ...
local L = addon_data.localization_table

addon_data.target = {}

--[[============================================================================================]]--
--[[===================================== SETTINGS RELATED =====================================]]--
--[[============================================================================================]]--

addon_data.target.default_settings = {
	enabled = true,
	width = 300,
	height = 12,
	fontsize = 10,
    point = "CENTER",
	rel_point = "CENTER",
	x_offset = 0,
	y_offset = -230,
	in_combat_alpha = 1.0,
	ooc_alpha = 0.25,
	backplane_alpha = 0.5,
	is_locked = false,
    show_left_text = true,
    show_right_text = true,
	show_offhand = true,
    show_border = true,
    classic_bars = true,
    fill_empty = true,
    main_r = 0.8, main_g = 0.1, main_b = 0.1, main_a = 1.0,
    main_text_r = 1.0, main_text_g = 1.0, main_text_b = 1.0, main_text_a = 1.0,
    off_r = 0.8, off_g = 0.1, off_b = 0.1, off_a = 1.0,
    off_text_r = 1.0, off_text_g = 1.0, off_text_b = 1.0, off_text_a = 1.0
}

addon_data.target.class = 'WARRIOR'
addon_data.target.guid = 0

addon_data.target.main_swing_timer = 0.00001
addon_data.target.prev_main_weapon_speed = 2
addon_data.target.main_weapon_speed = 2
addon_data.target.main_weapon_id = GetInventoryItemID("target", 16)
addon_data.target.main_speed_changed = false

addon_data.target.off_swing_timer = 0.00001
addon_data.target.prev_off_weapon_speed = 2
addon_data.target.off_weapon_speed = 2
addon_data.target.off_weapon_id = GetInventoryItemID("target", 17)
addon_data.target.has_offhand = false
addon_data.target.off_speed_changed = false

addon_data.target.LoadSettings = function()

    character_target_settings = addon_data.db.profile.target

    for setting, value in pairs(addon_data.target.default_settings) do
        if character_target_settings[setting] == nil then
            character_target_settings[setting] = value
        end
    end
end

--[[============================================================================================]]--
--[[====================================== LOGIC RELATED =======================================]]--
--[[============================================================================================]]--
addon_data.target.OnPlayerTargetChanged = function()
    if UnitExists("target") then
        addon_data.target.class = select(2, UnitClass("target"))
        addon_data.target.guid = UnitGUID("target")
        addon_data.target.ZeroizeSwingTimers()
    end
end

addon_data.target.OnInventoryChange = function()
    local new_main_guid = GetInventoryItemID("target", 16)
    local new_off_guid = GetInventoryItemID("target", 17)
    -- Check for a main hand weapon change
    if addon_data.target.main_weapon_id ~= new_main_guid then
        addon_data.target.UpdateMainWeaponSpeed()
        addon_data.target.ResetMainSwingTimer()
    end
    addon_data.target.main_weapon_id = new_main_guid
    -- Check for an off hand weapon change
    if addon_data.target.off_weapon_id ~= new_off_guid then
        addon_data.target.UpdateOffWeaponSpeed()
        addon_data.target.ResetOffSwingTimer()
    end
    addon_data.target.off_weapon_id = new_off_guid
end

addon_data.target.OnUpdate = function(elapsed)
    if character_target_settings.enabled and UnitExists("target") then
        -- Update the weapon speed
        addon_data.target.UpdateMainWeaponSpeed()
        addon_data.target.UpdateOffWeaponSpeed()
        -- FIXME: Temp fix until I can nail down the divide by zero error
        if addon_data.target.main_weapon_speed == 0 then
            addon_data.target.main_weapon_speed = 2
        end
        if addon_data.target.off_weapon_speed == 0 then
            addon_data.target.off_weapon_speed = 2
        end
        -- If the weapon speed changed for either hand then a buff occured and we need to modify the timers
        if addon_data.target.main_speed_changed or addon_data.target.off_speed_changed then
            -- only rescale a running swing (Treeston, LeftHandedGlove PR #26)
            if addon_data.target.main_swing_timer > 0 then
                local main_multiplier = addon_data.target.main_weapon_speed / addon_data.target.prev_main_weapon_speed
                addon_data.target.main_swing_timer = addon_data.target.main_swing_timer * main_multiplier
            end
            if addon_data.target.has_offhand and addon_data.target.off_swing_timer > 0 then
                local off_multiplier = (addon_data.target.off_weapon_speed / addon_data.target.prev_off_weapon_speed)
                addon_data.target.off_swing_timer = addon_data.target.off_swing_timer * off_multiplier
            end
        end
        -- Update the main hand swing timer
        addon_data.target.UpdateMainSwingTimer(elapsed)
        -- Update the off hand swing timer
        addon_data.target.UpdateOffSwingTimer(elapsed)
    end
    -- Update the visuals
        addon_data.target.UpdateVisualsOnUpdate()
end

addon_data.target.OnCombatLogUnfiltered = function(combat_info)
    local _, event, _, source_guid, _, _, _, dest_guid, _, _, _, _, spell_name, _ = unpack(combat_info)
    if (source_guid == addon_data.target.guid) then
        if (event == "SWING_DAMAGE") then
            local _, _, _, _, _, _, _, _, _, is_offhand = select(12, unpack(combat_info))
            if combat_info.offhand_unknown then
                is_offhand = addon_data.compat.SwingWasOffhand(addon_data.target)
            end
            if is_offhand then
                addon_data.target.ResetOffSwingTimer()
            else
                addon_data.target.ResetMainSwingTimer()
            end
        elseif (event == "SWING_MISSED") then
            local is_player = false
            if (dest_guid == addon_data.player.guid) then
                is_player = true
            end
            local miss_type, is_offhand = select(12, unpack(combat_info))
            if combat_info.offhand_unknown then is_offhand = nil end
            addon_data.core.MissHandler("target", miss_type, is_offhand, is_player)
        elseif (event == "SPELL_DAMAGE") or (event == "SPELL_MISSED") then
            addon_data.core.SpellHandler("target", spell_name)
        end
    end
    
end

addon_data.target.ResetMainSwingTimer = function()
    if UnitExists("target") then
        addon_data.target.main_swing_timer = addon_data.target.main_weapon_speed
    end
end

addon_data.target.ResetOffSwingTimer = function()
    if addon_data.target.has_offhand and UnitExists("target") then
        addon_data.target.off_swing_timer = addon_data.target.off_weapon_speed
    end
end

addon_data.target.ZeroizeSwingTimers = function()
    addon_data.target.main_swing_timer = 0.0001
    addon_data.target.off_swing_timer = 0.0001
end

addon_data.target.UpdateMainSwingTimer = function(elapsed)
    if character_target_settings.enabled and UnitExists("target") then
        if addon_data.target.main_swing_timer > 0 then
            addon_data.target.main_swing_timer = addon_data.target.main_swing_timer - elapsed
            if addon_data.target.main_swing_timer < 0 then
                addon_data.target.main_swing_timer = 0
            end
        end
    end
end

addon_data.target.UpdateOffSwingTimer = function(elapsed)
    if character_target_settings.enabled and UnitExists("target") then
        if addon_data.target.has_offhand then
            if addon_data.target.off_swing_timer > 0 then
                addon_data.target.off_swing_timer = addon_data.target.off_swing_timer - elapsed
                if addon_data.target.off_swing_timer < 0 then
                    addon_data.target.off_swing_timer = 0
                end
            end
        end
    end
end

addon_data.target.UpdateMainWeaponSpeed = function()
    if UnitExists("target") then
        -- Handle the nil when first selecting target
        if addon_data.target.main_weapon_speed then
            addon_data.target.prev_main_weapon_speed = addon_data.target.main_weapon_speed
        else
            addon_data.target.prev_main_weapon_speed, _ = UnitAttackSpeed("target")
        end
        -- Update the weapon speed
        addon_data.target.main_weapon_speed, _ = UnitAttackSpeed("target")
        if addon_data.target.main_weapon_speed ~= addon_data.target.prev_main_weapon_speed then
            addon_data.target.main_speed_changed = true
        else
            addon_data.target.main_speed_changed = false
        end
    end
end

addon_data.target.UpdateOffWeaponSpeed = function()
    if UnitExists("target") then
        -- Handle the nil when first selecting target
        if addon_data.target.off_weapon_speed then
            addon_data.target.prev_off_weapon_speed = addon_data.target.off_weapon_speed
        else
            _, addon_data.target.prev_off_weapon_speed = UnitAttackSpeed("target")
        end
        -- Update the weapon speed
        _, addon_data.target.off_weapon_speed = UnitAttackSpeed("target")
        -- Check to see if we have an off-hand
        if (not addon_data.target.off_weapon_speed) or (addon_data.target.off_weapon_speed == 0) then
            addon_data.target.has_offhand = false
        else
            addon_data.target.has_offhand = true
        end
        if addon_data.target.off_weapon_speed ~= addon_data.target.prev_off_weapon_speed then
            addon_data.target.off_speed_changed = true
        else
            addon_data.target.off_speed_changed = false
        end
    end
end

--[[============================================================================================]]--
--[[===================================== VISUALS RELATED ======================================]]--
--[[============================================================================================]]--
addon_data.target.UpdateVisualsOnUpdate = function()
    local settings = character_target_settings
    local frame = addon_data.target.frame
    if settings.enabled and UnitExists("target") then
        frame:Show()
        local main_speed = addon_data.target.main_weapon_speed
        local main_timer = addon_data.target.main_swing_timer
        -- FIXME: Handle divide by 0 error
        if main_speed == 0 then
            main_speed = 2
        end
        -- Update the main bars width
        main_width = math.min(settings.width - (settings.width * (main_timer / main_speed)), settings.width)
        if not settings.fill_empty then
            main_width = settings.width - main_width + 0.001
        end
        frame.main_bar:SetWidth(main_width)
        frame.main_spark:SetPoint('TOPLEFT', main_width - 8, 0)
        if main_width == settings.width or not settings.classic_bars or main_width == 0.001 then
            frame.main_spark:Hide()
        else
            frame.main_spark:Show()
        end
        -- Update the main bars text
        frame.main_left_text:SetText(L["Main-Hand"])
        frame.main_right_text:SetText(addon_data.utils.FormatTime(main_timer))
        -- Update the off hand bar
        if addon_data.target.has_offhand and settings.show_offhand then
            frame.off_bar:Show()
            if settings.show_left_text then
                frame.off_left_text:Show()
            else
                frame.off_left_text:Hide()
            end
            if settings.show_right_text then
                frame.off_right_text:Show()
            else
                frame.off_right_text:Hide()
            end
            local off_speed = addon_data.target.off_weapon_speed
            local off_timer = addon_data.target.off_swing_timer
            -- FIXME: Handle divide by 0 error
            if off_speed == 0 then
                off_speed = 2
            end
            -- Update the off-hand bar's width
            off_width = math.min(settings.width - (settings.width * (off_timer / off_speed)), settings.width)
            if not settings.fill_empty then
                off_width = settings.width - off_width + 0.001
            end
            frame.off_bar:SetWidth(off_width)
            frame.off_spark:SetPoint('BOTTOMLEFT', off_width - 8, 0)
            if off_width == settings.width or not settings.classic_bars or off_width == 0.001 then
                frame.off_spark:Hide()
            else
                frame.off_spark:Show()
            end
            -- Update the off-hand bar's text
            frame.off_left_text:SetText(L["Off-Hand"])
            frame.off_right_text:SetText(addon_data.utils.FormatTime(off_timer))
        else
            frame.off_bar:Hide()
            frame.off_left_text:Hide()
            frame.off_right_text:Hide()
        end
        -- Update the frame's appearance based on settings
        if addon_data.target.has_offhand and character_target_settings.show_offhand then
            frame:SetHeight((settings.height * 2) + 2)
        else
            frame:SetHeight(settings.height)
        end
        -- Update the alpha
        if addon_data.core.in_combat then
            frame:SetAlpha(settings.in_combat_alpha)
        else
            frame:SetAlpha(settings.ooc_alpha)
        end
    else
        frame:Hide()
    end
end

addon_data.target.UpdateVisualsOnSettingsChange = function()
    local frame = addon_data.target.frame
    local settings = character_target_settings
    if settings.enabled then
        frame:Show()
        frame:ClearAllPoints()
        frame:SetPoint(settings.point, UIParent, settings.rel_point, settings.x_offset, settings.y_offset)
        frame:SetWidth(settings.width)
        addon_data.compat.ApplyBackplane(frame.backplane, settings.show_border, settings.backplane_alpha)
        frame.main_bar:SetPoint("TOPLEFT", 0, 0)
        frame.main_bar:SetHeight(settings.height)
         if settings.classic_bars then
            frame.main_bar:SetTexture(addon_data.GetBarTexture())
        else
            frame.main_bar:SetTexture(addon_data.media .. "Background")
        end
        frame.main_bar:SetVertexColor(settings.main_r, settings.main_g, settings.main_b, settings.main_a)
        frame.main_spark:SetSize(16, settings.height)
        frame.main_left_text:SetPoint("TOPLEFT", 2, -(settings.height / 2) + (settings.fontsize / 2))
        frame.main_left_text:SetTextColor(settings.main_text_r, settings.main_text_g, settings.main_text_b, settings.main_text_a)
		frame.main_left_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
	
        frame.main_right_text:SetPoint("TOPRIGHT", -5, -(settings.height / 2) + (settings.fontsize / 2))
        frame.main_right_text:SetTextColor(settings.main_text_r, settings.main_text_g, settings.main_text_b, settings.main_text_a)
		frame.main_right_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
		
        frame.off_bar:SetPoint("BOTTOMLEFT", 0, 0)
        frame.off_bar:SetHeight(settings.height)
        if settings.classic_bars then
            frame.off_bar:SetTexture(addon_data.GetBarTexture())
        else
            frame.off_bar:SetTexture(addon_data.media .. "Background")
        end
        frame.off_bar:SetVertexColor(settings.off_r, settings.off_g, settings.off_b, settings.off_a)
        frame.off_spark:SetSize(16, settings.height)
        frame.off_left_text:SetPoint("BOTTOMLEFT", 2, (settings.height / 2) - (settings.fontsize / 2))
        frame.off_left_text:SetTextColor(settings.off_text_r, settings.off_text_g, settings.off_text_b, settings.off_text_a)
		frame.off_left_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
	
        frame.off_right_text:SetPoint("BOTTOMRIGHT", -5, (settings.height / 2) - (settings.fontsize / 2))
        frame.off_right_text:SetTextColor(settings.off_text_r, settings.off_text_g, settings.off_text_b, settings.off_text_a)
		frame.off_right_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
		
        if settings.show_left_text then
            frame.main_left_text:Show()
            frame.off_left_text:Show()
        else
            frame.main_left_text:Hide()
            frame.off_left_text:Hide()
        end
        if settings.show_right_text then
            frame.main_right_text:Show()
            frame.off_right_text:Show()
        else
            frame.main_right_text:Hide()
            frame.off_right_text:Hide()
        end
        if settings.show_offhand and addon_data.target.has_offhand then
            frame.off_bar:Show()
            if settings.show_left_text then
                frame.off_left_text:Show()
            else
                frame.off_left_text:Hide()
            end
            if settings.show_right_text then
                frame.off_right_text:Show()
            else
                frame.off_right_text:Hide()
            end
        else
            frame.off_bar:Hide()
            frame.off_left_text:Hide()
            frame.off_right_text:Hide()
        end
    else
        frame:Hide()
    end
end

addon_data.target.OnFrameDragStart = function()
    if not character_target_settings.is_locked then
        addon_data.target.frame:StartMoving()
    end
end

addon_data.target.OnFrameDragStop = function()
    local frame = addon_data.target.frame
    local settings = character_target_settings
    frame:StopMovingOrSizing()
    point, _, rel_point, x_offset, y_offset = frame:GetPoint()
    if x_offset < 20 and x_offset > -20 then
        x_offset = 0
    end
    settings.point = point
    settings.rel_point = rel_point
    settings.x_offset = addon_data.utils.SimpleRound(x_offset, 1)
    settings.y_offset = addon_data.utils.SimpleRound(y_offset, 1)
    addon_data.target.UpdateVisualsOnSettingsChange()
    addon_data.target.UpdateConfigPanelValues()
end

addon_data.target.InitializeVisuals = function()
    local settings = character_target_settings
    -- Create the frame
    addon_data.target.frame = CreateFrame("Frame", addon_name .. "TargetFrame", UIParent)
    local frame = addon_data.target.frame
    frame:SetMovable(true)
    frame:EnableMouse(not settings.is_locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", addon_data.target.OnFrameDragStart)
    frame:SetScript("OnDragStop", addon_data.target.OnFrameDragStop)
    -- Create the backplane
    frame.backplane = CreateFrame("Frame", addon_name .. "TargetBackdropFrame", frame, addon_data.compat.BackdropTemplate)
    frame.backplane:SetPoint('TOPLEFT', -9, 9)
    frame.backplane:SetPoint('BOTTOMRIGHT', 9, -9)
    frame.backplane:SetFrameStrata('BACKGROUND')
    -- Create the main hand bar
    frame.main_bar = frame:CreateTexture(nil,"ARTWORK")
    -- Create the main spark
    frame.main_spark = frame:CreateTexture(nil,"OVERLAY")
    frame.main_spark:SetTexture(addon_data.media .. "Spark")
    -- Create the main hand bar left text
    frame.main_left_text = frame:CreateFontString(nil, "OVERLAY")
    frame.main_left_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
    frame.main_left_text:SetJustifyV("MIDDLE")
    frame.main_left_text:SetJustifyH("LEFT")
    -- Create the main hand bar right text
    frame.main_right_text = frame:CreateFontString(nil, "OVERLAY")
    frame.main_right_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
    frame.main_right_text:SetJustifyV("MIDDLE")
    frame.main_right_text:SetJustifyH("RIGHT")
    -- Create the off hand bar
    frame.off_bar = frame:CreateTexture(nil,"ARTWORK")
    -- Create the off spark
    frame.off_spark = frame:CreateTexture(nil,"OVERLAY")
    frame.off_spark:SetTexture(addon_data.media .. "Spark")
    -- Create the off hand bar left text
    frame.off_left_text = frame:CreateFontString(nil, "OVERLAY")
    frame.off_left_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
    frame.off_left_text:SetJustifyV("MIDDLE")
    frame.off_left_text:SetJustifyH("LEFT")
    -- Create the off hand bar right text
    frame.off_right_text = frame:CreateFontString(nil, "OVERLAY")
    frame.off_right_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
    frame.off_right_text:SetJustifyV("MIDDLE")
    frame.off_right_text:SetJustifyH("RIGHT")
    -- Show it off
    addon_data.target.UpdateVisualsOnSettingsChange()
    addon_data.target.UpdateVisualsOnUpdate()
    frame:Show()
end
