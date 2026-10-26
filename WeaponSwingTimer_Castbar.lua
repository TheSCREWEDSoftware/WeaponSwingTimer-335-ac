local addon_name, addon_data = ...
local L = addon_data.localization_table
--- define addon structure from the above local variable
addon_data.castbar = {}
--- declare array for ranks of all abilities, cast times, cooldown, based on spell ID
addon_data.castbar.shot_spell_ids = {
	[5384] = {spell_name = L["Feign Death"], rank = nil, cast_time = nil, cooldown = nil},
	[19506] = {spell_name = L["Trueshot Aura"], rank = 1, cast_time = nil, cooldown = nil},
	[20905] = {spell_name = L["Trueshot Aura"], rank = 2, cast_time = nil, cooldown = nil},
	[20906] = {spell_name = L["Trueshot Aura"], rank = 3, cast_time = nil, cooldown = nil},
    [2643] = {spell_name = L["Multi-Shot"], rank = 1, cast_time = 0.5, cooldown = 10},
    [14288] = {spell_name = L["Multi-Shot"], rank = 2, cast_time = 0.5, cooldown = 10},
    [14289] = {spell_name = L["Multi-Shot"], rank = 3, cast_time = 0.5, cooldown = 10},
    [14290] = {spell_name = L["Multi-Shot"], rank = 4, cast_time = 0.5, cooldown = 10},
    [25294] = {spell_name = L["Multi-Shot"], rank = 5, cast_time = 0.5, cooldown = 10},
	[27021] = {spell_name = L["Multi-Shot"], rank = 6, cast_time = 0.5, cooldown = 10},
    [19434] = {spell_name = L["Aimed Shot"], rank = 1, cast_time = 3, cooldown = 6},
    [20900] = {spell_name = L["Aimed Shot"], rank = 2, cast_time = 3, cooldown = 6},
    [20901] = {spell_name = L["Aimed Shot"], rank = 3, cast_time = 3, cooldown = 6},
    [20902] = {spell_name = L["Aimed Shot"], rank = 4, cast_time = 3, cooldown = 6},
    [20903] = {spell_name = L["Aimed Shot"], rank = 5, cast_time = 3, cooldown = 6},
    [20904] = {spell_name = L["Aimed Shot"], rank = 6, cast_time = 3, cooldown = 6},
    [27065] = {spell_name = L["Aimed Shot"], rank = 7, cast_time = 3, cooldown = 6},
    [34120] = {spell_name = L["Steady Shot"], rank = nil, cast_time = 2, cooldown = nil},
    [5019] = {spell_name = L["Shoot"], rank = nil, cast_time = nil, cooldown = nil}
}
--- is spell multi-shot defined by spell_id
addon_data.castbar.is_spell_multi_shot = function(spell_id)
    if (spell_id == 2643) or (spell_id == 14288) or (spell_id == 14289) or 
       (spell_id == 14290) or (spell_id == 25294) or (spell_id == 27021) then
            return true
    else
            return false
    end
end
--- is spell aimed shot defined by spell_id
addon_data.castbar.is_spell_aimed_shot = function(spell_id)
    if (spell_id == 19434) or (spell_id == 20900) or (spell_id == 20901) or 
       (spell_id == 20902) or (spell_id == 20903) or (spell_id == 20904) or (spell_id == 27065) then
            return true
    else
            return false
    end
end
--- is spell steady shot defined by spell_id
addon_data.castbar.is_spell_steady_shot = function(spell_id)
    return (spell_id == 34120)
end
--- is spell auto shot defined by spell_id
addon_data.castbar.is_spell_auto_shot = function(spell_id)
    return (spell_id == 75)
end
--- is spell shoot defined by spell_id
addon_data.castbar.is_spell_shoot = function(spell_id)
    return (spell_id == 5019)
end
--- default settings to be loaded on initial load and reset to default
addon_data.castbar.default_settings = {
	enabled = true,
	width = 300,
	height = 12,
	fontsize = 12,
    point = "CENTER",
	rel_point = "CENTER",
	x_offset = 0,
	y_offset = 0,
	in_combat_alpha = 1.0,
	--ooc_alpha = 0.5,
	backplane_alpha = 0.5,
    show_cast_text = true,
    show_aimedshot_cast_bar = true,
    show_multishot_cast_bar = true,
    show_steadyshot_cast_bar = true,
    show_latency_bars = false,
    show_border = true,
    is_locked = false
}
--- Initializing variables for calculations and function calls

addon_data.castbar.casting = false
addon_data.castbar.casting_shot = false
addon_data.castbar.casting_spell_id = 0
addon_data.castbar.cast_timer = 0.1
addon_data.castbar.cast_time = 0.1
addon_data.castbar.last_failed_time = GetTime()
addon_data.castbar.cast_start_time = GetTime()
addon_data.castbar.hitcount = 0
addon_data.castbar.initial_pushback_time = 0
addon_data.castbar.initial_cast_time = 0
addon_data.castbar.total_pushback = 0
addon_data.castbar.cast_end_time = 0 -- idle at login: hidden, no flash

addon_data.castbar.CastPushback = function()
	if addon_data.castbar.casting_shot then
	        -- https://wow.gamepedia.com/index.php?title=Interrupt&oldid=305918
        addon_data.castbar.pushbackValue = addon_data.castbar.pushbackValue or 1

		if ((GetTime() - addon_data.castbar.cast_start_time) < 1) and (addon_data.castbar.hitcount < 1) then
			addon_data.castbar.initial_pushback_time = GetTime() - addon_data.castbar.cast_start_time
		end

		if addon_data.castbar.initial_pushback_time > 0 then
			addon_data.castbar.cast_time = addon_data.castbar.cast_time + addon_data.castbar.initial_pushback_time
			addon_data.castbar.initial_pushback_time = 0
			addon_data.castbar.pushbackValue = 1
		else
			addon_data.castbar.cast_time = addon_data.castbar.cast_time + addon_data.castbar.pushbackValue
		end

		addon_data.castbar.hitcount = addon_data.castbar.hitcount + 1

        addon_data.castbar.pushbackValue = max(addon_data.castbar.pushbackValue - 0.2, 0.2)
		
		return
	end
end

-- Selection of starting a timer for casting multi and handling of stopping auto timer from starting
addon_data.castbar.StartCastingSpell = function(spell_id)
    local settings = character_castbar_settings

    if (GetTime() - addon_data.castbar.last_failed_time) > 0 then
        if not addon_data.castbar.casting and UnitCanAttack('player', 'target') then
            spell_name, _, _, cast_time, _, _, _ = addon_data.compat.GetSpellInfo(spell_id)
            if cast_time == nil then
			
                return 
            end
            if not addon_data.castbar.is_spell_auto_shot(spell_id) and 
               not addon_data.castbar.is_spell_shoot(spell_id) and cast_time > 0 then
                    addon_data.castbar.casting = true
            end

			if (not addon_data.castbar.casting_shot) and
               ((addon_data.castbar.is_spell_multi_shot(spell_id) and settings.show_multishot_cast_bar) or
                (addon_data.castbar.is_spell_aimed_shot(spell_id) and settings.show_aimedshot_cast_bar) or
                (addon_data.castbar.is_spell_steady_shot(spell_id) and settings.show_steadyshot_cast_bar)) then
				addon_data.castbar.cast_start_time = GetTime()
				addon_data.castbar.casting_shot = true
				addon_data.castbar.casting_spell_id = spell_id
				addon_data.castbar.pushbackValue = 1
				addon_data.castbar.initial_pushback_time = 0
				addon_data.castbar.initial_cast_time = cast_time
                    
				addon_data.castbar.cast_timer = 0
				addon_data.castbar.frame.spell_bar:SetVertexColor(0.7, 0.4, 0, 1)

				if settings.show_latency_bars then
					local latency = addon_data.compat.GetLatency()
					addon_data.castbar.cast_time = addon_data.castbar.cast_time + (latency / 1000)
				end
				if settings.show_cast_text then
					addon_data.castbar.frame.spell_text_center:SetText(spell_name)
				end
			end	
		end
	end
end

addon_data.castbar.LoadSettings = function()

    character_castbar_settings = addon_data.db.profile.castbar

    for setting, value in pairs(addon_data.castbar.default_settings) do
        if character_castbar_settings[setting] == nil then
            character_castbar_settings[setting] = value
        end
    end

    -- only load castbar if hunter class, since it's only used for multi and aimed shot
    if character_castbar_settings.enabled == nil then
        local _, class = UnitClass("player")
        character_castbar_settings.enabled =
            (class == "HUNTER")
    end

    -- One-time tooltip creation
    if not addon_data.castbar.scan_tip then
        addon_data.castbar.scan_tip = CreateFrame("GameTooltip", "WSTScanTip", nil, "GameTooltipTemplate")
        addon_data.castbar.scan_tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
end


--[[============================================================================================]]--
--[[====================================== LOGIC RELATED =======================================]]--
--[[============================================================================================]]--
--- Buffs and debuffs change casting speeds, which is multiplied by the cast time
--- -----------------------------------------------------------------------------
--- Anything that changes cast times should go here. Need to add other forms of debuffs
--- berserk haste is a simple calculation to derive the percent of berserking haste provided to the player from their health percent

addon_data.castbar.UpdateCastTimer = function(elapsed)
	
	local base_cast_time = addon_data.castbar.shot_spell_ids[addon_data.castbar.casting_spell_id].cast_time
	
	if (addon_data.castbar.cast_timer < 0.25) then
		addon_data.castbar.cast_time = base_cast_time * addon_data.hunter.range_cast_speed_modifer
	end
	
    -- use the client's real cast window (haste, pushback)
    local casting_name, _, _, _, start_ms, end_ms = UnitCastingInfo("player")
    if casting_name and start_ms and end_ms and end_ms > start_ms then
        addon_data.castbar.cast_start_time = start_ms / 1000
        addon_data.castbar.cast_time = (end_ms - start_ms) / 1000
    end
    addon_data.castbar.cast_timer = GetTime() - addon_data.castbar.cast_start_time
    if addon_data.castbar.cast_timer > addon_data.castbar.cast_time + 0.5 then
        addon_data.castbar.OnUnitSpellCastFailed('player', 1)
    end
	
	addon_data.castbar.total_pushback = addon_data.castbar.cast_time - addon_data.castbar.initial_cast_time
end

-- Hunters with a ranged weapon
addon_data.castbar.IsRelevant = function()
    if addon_data.core.preview then return true end
    if character_core_settings and character_core_settings.only_class_bars == false then return true end
    local _, class = UnitClass("player")
    return class == "HUNTER" and GetInventoryItemID("player", INVSLOT_RANGED or 18) ~= nil
end

addon_data.castbar.OnUpdate = function(elapsed)
    local settings = character_castbar_settings
    local any_bar = settings.show_multishot_cast_bar or settings.show_aimedshot_cast_bar or settings.show_steadyshot_cast_bar
    if not (settings.enabled and any_bar and addon_data.castbar.IsRelevant()) then
        addon_data.castbar.frame:Hide()
        return
    elseif not addon_data.castbar.frame:IsShown() then
        addon_data.castbar.UpdateVisualsOnSettingsChange()
    end
    if settings.enabled then
		local curr_time = GetTime()
        -- Update the cast bar timers
        if addon_data.castbar.casting_shot then
            addon_data.castbar.UpdateCastTimer(elapsed)
        end
        -- Update the visuals
        addon_data.castbar.UpdateVisualsOnUpdate()
		
    end
end

-- Using combat log to detect pushback hits as well as starting to use spell cast events to replace the old version of detection that was implied
addon_data.castbar.OnCombatLogUnfiltered = function(combat_info)
    local _, event, _, casterID, _, _, _, targetID, targetName, _, _, spellID, name, _ = unpack(combat_info)
	if casterID == UnitGUID("player") then
	
		if event == "SPELL_CAST_START" then
		  
				addon_data.hunter.FeignStatus = false
				if addon_data.castbar.is_spell_multi_shot(spellID) or
                   addon_data.castbar.is_spell_aimed_shot(spellID) or
                   addon_data.castbar.is_spell_steady_shot(spellID) then
					addon_data.castbar.StartCastingSpell(spellID)
					
				end
				
		return end
	
		if event == "SPELL_CAST_SUCCESS" then

		return end
	end		
		
	
	if event == "SWING_MISSED" or event == "RANGE_MISSED" or event == "SPELL_MISSED" then	return end
	if event == "SWING_DAMAGE" or event == "ENVIRONMENTAL_DAMAGE" or event == "RANGE_DAMAGE" or event == "SPELL_DAMAGE" then	
	
		if targetID == UnitGUID("player") then
			addon_data.castbar.CastPushback()
		end
	return end
end

--- upon spell cast succeeded, check if is auto shot and reset timer, adjust ranged speed based on haste. 
--- If not auto shot, set bar to green *commented out
addon_data.castbar.OnUnitSpellCastSucceeded = function(unit, spell_id)

	local settings = character_castbar_settings

  if unit == 'player' then
	
	      addon_data.castbar.casting = false
        
        if addon_data.castbar.shot_spell_ids[spell_id] then
            spell_name = addon_data.castbar.shot_spell_ids[spell_id].spell_name

			addon_data.castbar.casting_spell_id = 0
            addon_data.castbar.casting_shot = false
			-- only show green bar overlay if setting is enabled
			local spell_aimed_enabled = (addon_data.castbar.is_spell_aimed_shot(spell_id) and settings.show_aimedshot_cast_bar)
			local spell_multi_enabled = (addon_data.castbar.is_spell_multi_shot(spell_id) and settings.show_multishot_cast_bar)
			local spell_steady_enabled = (addon_data.castbar.is_spell_steady_shot(spell_id) and settings.show_steadyshot_cast_bar)
			if (spell_aimed_enabled or spell_multi_enabled or spell_steady_enabled) then
				addon_data.castbar.frame.spell_bar:SetVertexColor(0, 0.5, 0, 1)
				addon_data.castbar.frame.spell_bar:SetWidth(character_castbar_settings.width)
				addon_data.castbar.frame.spell_bar_text:SetText("0.0")
			end
            
        end

    end
end

addon_data.castbar.OnUnitSpellCastFailed = function(unit, spell_id)
    local settings = character_castbar_settings
    local frame = addon_data.castbar.frame
	-- only care about if multi fails to cast, so ignore others
    if unit == 'player' and (addon_data.castbar.is_spell_multi_shot(spell_id) or
                             addon_data.castbar.is_spell_aimed_shot(spell_id) or
                             addon_data.castbar.is_spell_steady_shot(spell_id)) then

        addon_data.castbar.last_failed_time = GetTime()
        addon_data.castbar.casting = false
		addon_data.castbar.pushbackValue = 1
		addon_data.castbar.initial_pushback_time = 0
		addon_data.castbar.hitcount = 0
		
        local spell_aimed_enabled = (addon_data.castbar.is_spell_aimed_shot(spell_id) and settings.show_aimedshot_cast_bar)
		local spell_multi_enabled = (addon_data.castbar.is_spell_multi_shot(spell_id) and settings.show_multishot_cast_bar)
		local spell_steady_enabled = (addon_data.castbar.is_spell_steady_shot(spell_id) and settings.show_steadyshot_cast_bar)
        if (addon_data.castbar.casting_spell_id > 0) and (spell_aimed_enabled or spell_multi_enabled or spell_steady_enabled) then
		
            addon_data.castbar.casting_shot = false
            addon_data.castbar.casting_spell_id = 0
			if spell_aimed_enabled or spell_multi_enabled or spell_steady_enabled then
				addon_data.castbar.frame.spell_bar:SetVertexColor(0.7, 0, 0, 1)
				if character_castbar_settings.show_cast_text then
					frame.spell_text_center:SetText(L["Failed"])
				end
				frame.spell_bar:SetWidth(settings.width)
			end
        end
    end
end

addon_data.castbar.OnUnitSpellCastInterrupted = function(unit, spell_id)
    local settings = character_castbar_settings
	local frame = addon_data.castbar.frame
	if unit == 'player' and (addon_data.castbar.is_spell_multi_shot(spell_id) or
                             addon_data.castbar.is_spell_aimed_shot(spell_id) or
                             addon_data.castbar.is_spell_steady_shot(spell_id)) then
	
        addon_data.castbar.casting = false
		addon_data.castbar.pushbackValue = 1
		addon_data.castbar.initial_pushback_time = 0
		addon_data.castbar.hitcount = 0
		
		local spell_aimed_enabled = (addon_data.castbar.is_spell_aimed_shot(spell_id) and settings.show_aimedshot_cast_bar)
		local spell_multi_enabled = (addon_data.castbar.is_spell_multi_shot(spell_id) and settings.show_multishot_cast_bar)
		local spell_steady_enabled = (addon_data.castbar.is_spell_steady_shot(spell_id) and settings.show_steadyshot_cast_bar)
        if (addon_data.castbar.casting_spell_id > 0) and (spell_aimed_enabled or spell_multi_enabled or spell_steady_enabled) then
            addon_data.castbar.casting_shot = false
            addon_data.castbar.casting_spell_id = 0
			
			if spell_aimed_enabled or spell_multi_enabled or spell_steady_enabled then
				frame.spell_bar:SetVertexColor(0.7, 0, 0, 1)
				if settings.show_cast_text then
					frame.spell_text_center:SetText(L["Interrupted"])
				end
				frame.spell_bar:SetWidth(settings.width)
			end
        end
    end
end

--- Updating and initializing visuals
--- ---------------------------------
addon_data.castbar.UpdateVisualsOnUpdate = function()
    local settings = character_castbar_settings
    local frame = addon_data.castbar.frame

    if addon_data.core.in_combat or addon_data.castbar.casting_shot then
		if addon_data.castbar.casting_shot then
			addon_data.castbar.cast_end_time = nil
			frame.spell_bar_text:SetText(addon_data.utils.FormatTime(addon_data.castbar.cast_time - addon_data.castbar.cast_timer, true))
			frame:SetAlpha(1)
			frame.spell_bar:SetVertexColor(0.7, 0.4, 0, 1)
			new_width = settings.width * (addon_data.castbar.cast_timer / addon_data.castbar.cast_time)
			new_width = math.min(new_width, settings.width)
			frame.spell_bar:SetWidth(new_width)
			frame.spell_spark:SetPoint('TOPLEFT', new_width - 8, 0)
			if new_width == settings.width or not settings.classic_bars then
				frame.spell_spark:Hide()
			else
				frame.spell_spark:Show()
			end
		else
			-- No fade animation: keep the final result (done / failed / interrupted)
			-- on screen for a moment, then hide it in one step.
			addon_data.castbar.cast_end_time = addon_data.castbar.cast_end_time or GetTime()
			if GetTime() - addon_data.castbar.cast_end_time < 0.6 then
				frame:SetAlpha(1)
			else
				frame:SetAlpha(0)
				frame:SetSize(settings.width, settings.height)
				frame.spell_text_center:SetText("")
				frame.spell_bar_text:SetText("")
			end
			frame.spell_spark:Hide()
		end
		if settings.show_latency_bars then
				if addon_data.castbar.casting_shot then
				frame.cast_latency:Show()
				local latency = addon_data.compat.GetLatency()
				lag_width = settings.width * ((latency / 1000) / addon_data.castbar.cast_time)
				frame.cast_latency:SetWidth(lag_width)
			else
				frame.cast_latency:Hide()
		end
	end
	else
		frame.spell_bar:SetVertexColor(0.2, 0.2, 0.2, 1)
		frame:SetSize(settings.width, settings.height)
		frame.spell_spark:Hide()
		-- placeholder only while the options window is open
		local options_open = InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown()
        if not (settings.is_locked) and options_open then
			frame.spell_text_center:SetText(L["Spell Bar Unlocked"])
			frame:SetAlpha(1)
		else
			frame.spell_text_center:SetText("")
			frame.spell_bar_text:SetText("")
			frame:SetAlpha(0)
		end
    end
end

addon_data.castbar.UpdateVisualsOnSettingsChange = function()
    local settings = character_castbar_settings
    local frame = addon_data.castbar.frame
	if settings.enabled and (settings.show_multishot_cast_bar or settings.show_aimedshot_cast_bar or settings.show_steadyshot_cast_bar) and addon_data.castbar.IsRelevant() then
        frame:EnableMouse(not settings.is_locked)
        frame:Show()
        frame:ClearAllPoints()
        frame:SetPoint(settings.point, UIParent, settings.rel_point, settings.x_offset, settings.y_offset)
        addon_data.compat.ApplyBackplane(frame.backplane, settings.show_border, settings.backplane_alpha)
        frame:SetAlpha(1)

        frame.spell_bar_text:SetPoint("TOPRIGHT", -5, -(settings.height / 2) + (settings.fontsize / 2))
        frame.spell_bar_text:SetTextColor(1.0, 1.0, 1.0, 1.0)
		frame.spell_bar_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
		
        frame.spell_bar:SetPoint("TOPLEFT", 0, 0)
        frame.spell_bar:SetHeight(settings.height)

		frame.spell_bar:SetTexture(addon_data.media .. "Background")
        frame.spell_spark:SetSize(16, settings.height)
        frame.spell_text_center:SetPoint("TOP", 2, -(settings.height / 2) + (settings.fontsize / 2))
		frame.spell_text_center:SetFont(addon_data.GetBarFont(), settings.fontsize)
		
		frame.cast_latency:SetHeight(settings.height)
        frame.cast_latency:SetPoint("TOPLEFT", 0, 0)
        addon_data.compat.SetColorTexture(frame.cast_latency, 1, 0, 0, 0.75)
        if settings.show_latency_bars then
            frame.cast_latency:Show()
        else
            frame.cast_latency:Hide()
        end

        if settings.show_cast_text then
            frame.spell_text_center:Show()
            frame.spell_bar_text:Show()
        else
            frame.spell_text_center:Hide()
            frame.spell_bar_text:Hide()
        end
    else
        frame:Hide()
    end
end

addon_data.castbar.OnFrameDragStart = function()
    if not character_castbar_settings.is_locked then
        addon_data.castbar.frame:StartMoving()
    end
end

addon_data.castbar.OnFrameDragStop = function()
    local frame = addon_data.castbar.frame
    local settings = character_castbar_settings
    frame:StopMovingOrSizing()
    point, _, rel_point, x_offset, y_offset = frame:GetPoint()
    if x_offset < 20 and x_offset > -20 then
        x_offset = 0
    end
    settings.point = point
    settings.rel_point = rel_point
    settings.x_offset = addon_data.utils.SimpleRound(x_offset, 1)
    settings.y_offset = addon_data.utils.SimpleRound(y_offset, 1)
    addon_data.castbar.UpdateVisualsOnSettingsChange()
    addon_data.castbar.UpdateConfigPanelValues()
end

addon_data.castbar.InitializeVisuals = function()
    local settings = character_castbar_settings
    -- Create the frame
    addon_data.castbar.frame = CreateFrame("Frame", addon_name .. "HunterCastbarFrame", UIParent)
    local frame = addon_data.castbar.frame
    frame:SetMovable(true)
    frame:EnableMouse(not settings.is_locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", addon_data.castbar.OnFrameDragStart)
    frame:SetScript("OnDragStop", addon_data.castbar.OnFrameDragStop)
    -- Create the backplane
    frame.backplane = CreateFrame("Frame", addon_name .. "HunterBackdropFrame", frame, addon_data.compat.BackdropTemplate)
    frame.backplane:SetPoint('TOPLEFT', -9, 9)
    frame.backplane:SetPoint('BOTTOMRIGHT', 9, -9)
    frame.backplane:SetFrameStrata('BACKGROUND')

    -- Create the range spell shot bar
    frame.spell_bar = frame:CreateTexture(nil,"ARTWORK")
    -- Create the spell bar text
    frame.spell_bar_text = frame:CreateFontString(nil,"OVERLAY")
    frame.spell_bar_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
    frame.spell_bar_text:SetJustifyV("MIDDLE")
    frame.spell_bar_text:SetJustifyH("CENTER")
    -- Create the spell spark
    frame.spell_spark = frame:CreateTexture(nil,"OVERLAY")
    frame.spell_spark:SetTexture(addon_data.media .. "Spark")
    -- Create the range spell shot bar center text
    frame.spell_text_center = frame:CreateFontString(nil,"OVERLAY")
    frame.spell_text_center:SetFont(addon_data.GetBarFont(), settings.fontsize)
    frame.spell_text_center:SetTextColor(1, 1, 1, 1)
    frame.spell_text_center:SetJustifyV("MIDDLE")
    frame.spell_text_center:SetJustifyH("LEFT")
    -- Create the latency bar
    frame.cast_latency = frame:CreateTexture(nil,"OVERLAY")
    -- Show it off
    addon_data.castbar.UpdateVisualsOnSettingsChange()
    addon_data.castbar.UpdateVisualsOnUpdate()
    frame:Show()
end
