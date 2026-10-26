local addon_name, addon_data = ...
local L = addon_data.localization_table

--- define addon structure from the above local variable
addon_data.hunter = {}
--- declare array for ranks of all abilities, cast times, cooldown, based on spell ID
addon_data.hunter.shot_spell_ids = {
    [75] = {spell_name = L["Auto Shot"], rank = nil, cast_time = 0.5, cooldown = nil},
	[5384] = {spell_name = L["Feign Death"], rank = nil, cast_time = nil, cooldown = nil},
	[19506] = {spell_name = L["Trueshot Aura"], rank = 1, cast_time = nil, cooldown = nil},
	[20905] = {spell_name = L["Trueshot Aura"], rank = 2, cast_time = nil, cooldown = nil},
	[20906] = {spell_name = L["Trueshot Aura"], rank = 3, cast_time = nil, cooldown = nil},
    [2643] = {spell_name = L["Multi-Shot"], rank = 1, cast_time = 0.45, cooldown = 10},
    [14288] = {spell_name = L["Multi-Shot"], rank = 2, cast_time = 0.45, cooldown = 10},
    [14289] = {spell_name = L["Multi-Shot"], rank = 3, cast_time = 0.45, cooldown = 10},
    [14290] = {spell_name = L["Multi-Shot"], rank = 4, cast_time = 0.45, cooldown = 10},
    [25294] = {spell_name = L["Multi-Shot"], rank = 5, cast_time = 0.45, cooldown = 10},
	[27021] = {spell_name = L["Multi-Shot"], rank = 6, cast_time = 0.45, cooldown = 10},
    [19434] = {spell_name = L["Aimed Shot"], rank = 1, cast_time = 3, cooldown = 6},
    [20900] = {spell_name = L["Aimed Shot"], rank = 2, cast_time = 3, cooldown = 6},
    [20901] = {spell_name = L["Aimed Shot"], rank = 3, cast_time = 3, cooldown = 6},
    [20902] = {spell_name = L["Aimed Shot"], rank = 4, cast_time = 3, cooldown = 6},
    [20903] = {spell_name = L["Aimed Shot"], rank = 5, cast_time = 3, cooldown = 6},
    [20904] = {spell_name = L["Aimed Shot"], rank = 6, cast_time = 3, cooldown = 6},
	[27065] = {spell_name = L["Aimed Shot"], rank = 7, cast_time = 3, cooldown = 6},
    [5019] = {spell_name = L["Shoot"], rank = nil, cast_time = nil, cooldown = nil}
}
--- is spell multi-shot defined by spell_id
addon_data.hunter.is_spell_multi_shot = function(spell_id)
    if (spell_id == 2643) or (spell_id == 14288) or (spell_id == 14289) or 
       (spell_id == 14290) or (spell_id == 25294) or (spell_id == 27021) then
            return true
    else
            return false
    end
end
--- is spell aimed shot defined by spell_id
addon_data.hunter.is_spell_aimed_shot = function(spell_id)
    if (spell_id == 19434) or (spell_id == 20900) or (spell_id == 20901) or 
       (spell_id == 20902) or (spell_id == 20903) or (spell_id == 20904) or (spell_id == 27065) then
            return true
    else
            return false
    end
end
--- is spell auto shot defined by spell_id
addon_data.hunter.is_spell_auto_shot = function(spell_id)
    return (spell_id == 75)
end
--- is spell shoot defined by spell_id
addon_data.hunter.is_spell_shoot = function(spell_id)
    return (spell_id == 5019)
end
--- default settings to be loaded on initial load and reset to default
addon_data.hunter.default_settings = {
	enabled = true,
	width = 300,
	height = 12,
	fontsize = 12,
    point = "CENTER",
	rel_point = "CENTER",
	x_offset = 0,
	y_offset = -260,
	in_combat_alpha = 1.0,
	ooc_alpha = 0.0,
	backplane_alpha = 0.5,
	is_locked = false,
    show_text = true,
	show_autoshot_delay_timer = true,
    show_border = true,
    classic_bars = true,
    one_bar = false,
    cooldown_r = 0.15, cooldown_g = 0.6, cooldown_b = 0.15, cooldown_a = 1.0,
}
-- Shot bar: needs a ranged weapon or wand; by default only for Auto Shot / wand classes
local ranged_classes = { HUNTER = true, MAGE = true, PRIEST = true, WARLOCK = true }
addon_data.hunter.IsRelevant = function()
    if addon_data.core.preview then return true end
    if not GetInventoryItemID("player", INVSLOT_RANGED or 18) then return false end
    if character_core_settings and character_core_settings.only_class_bars == false then return true end
    local _, class = UnitClass("player")
    return ranged_classes[class] and true or false
end

--- Initializing variables for calculations and function calls
addon_data.hunter.shooting = false
-- added check below for range speed to default 3 on initialize 
addon_data.hunter.range_speed = 3
-- No Auto Shot cast time in WotLK (watchyoursixx's wotlk-master)
addon_data.hunter.auto_cast_time = 0.01
addon_data.hunter.shot_timer = 0.01
addon_data.hunter.last_shot_time = GetTime()
addon_data.hunter.auto_shot_ready = true
addon_data.hunter.FeignStatus = false
addon_data.hunter.FeignFullReset = false
addon_data.hunter.range_auto_speed_modified = 1
addon_data.hunter.base_speed = 1
addon_data.hunter.spell_GCD = 0
addon_data.hunter.spell_GCD_Time = 0

addon_data.hunter.casting = false
addon_data.hunter.casting_auto = false
addon_data.hunter.range_cast_speed_modifer = 1

addon_data.hunter.has_moved = false

-- handling of stopping auto timer from starting
addon_data.hunter.StartCastingSpell = function(spell_id)
    
    if not addon_data.hunter.casting and UnitCanAttack('player', 'target') then
        local spell_name, _, _, cast_time, _, _, _ = addon_data.compat.GetSpellInfo(spell_id)
        if cast_time == nil then
			
            return 
        end
        if not addon_data.hunter.is_spell_auto_shot(spell_id) and 
			not addon_data.hunter.is_spell_shoot(spell_id) and cast_time > 0 then
               addon_data.hunter.casting = true
        end
	end
end

addon_data.hunter.LoadSettings = function()
    -- Ensure the alias is pointing at the current profile table
    character_hunter_settings = addon_data.db.profile.hunter

    for setting, value in pairs(addon_data.hunter.default_settings) do
        if character_hunter_settings[setting] == nil then
            character_hunter_settings[setting] = value
        end
    end
        if character_hunter_settings.enabled == nil then
        local _, class = UnitClass("player")
        character_hunter_settings.enabled = (class == "HUNTER" or class == "MAGE" or class == "PRIEST" or class == "WARLOCK")
    end
    
    -- One-time tooltip initialize
    if not addon_data.hunter.scan_tip then
        addon_data.hunter.scan_tip = CreateFrame("GameTooltip", "WSTScanTip", nil, "GameTooltipTemplate")
        addon_data.hunter.scan_tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
end

--[[============================================================================================]]--
--[[====================================== LOGIC RELATED =======================================]]--
--[[============================================================================================]]--
-- Replaced update info with this instead, checking weapon id every time inventory is changed for simplicity
addon_data.hunter.OnInventoryChange = function()
	local _, class, _ = UnitClass("player")
	if (class == "HUNTER" or class == "MAGE" or class == "PRIEST" or class == "WARLOCK") then
		addon_data.hunter.base_speed = addon_data.GetRangedBaseSpeed()
	end
end	

--- Reset Swing Timer unhasted separately due to feign and other spells
addon_data.hunter.FeignDeath = function()
    addon_data.hunter.last_shot_time = GetTime()
	if not addon_data.hunter.FeignFullReset then
		local current_speed = UnitRangedDamage("player")
		if not current_speed or current_speed == 0 then
			current_speed = addon_data.GetRangedBaseSpeed()
		end
		addon_data.hunter.range_speed = current_speed + 0.15
		addon_data.hunter.FeignFullReset = true
	end
    addon_data.hunter.ResetShotTimer()
end

-- Modified to use base speed and current ranged speed, to get the haste modifiers. This is used in multi-shot cast bar to provide an accurate bar, as well as multi clip
addon_data.hunter.UpdateRangeCastSpeedModifier = function()
	local _, class, _ = UnitClass("player")
	
	if addon_data.hunter.base_speed == 1 and (class == "HUNTER" or class == "MAGE" or class == "PRIEST" or class == "WARLOCK") then 
		addon_data.hunter.base_speed = addon_data.GetRangedBaseSpeed()
	else
		local range_speed, _, _, _, _, _ = UnitRangedDamage("player")
		-- added case for if range speed returns nil or 0
		-- zero base speed guard (Matthew Carlis, SixxFix PR #48)
		if range_speed == nil or range_speed == 0 or not addon_data.hunter.base_speed or addon_data.hunter.base_speed == 0 then
			range_speed = 1
            addon_data.hunter.range_cast_speed_modifer = 1
		else
			addon_data.hunter.range_cast_speed_modifer = range_speed / addon_data.hunter.base_speed
		end
	end
end


--- Update timer for auto shot based on various conditions
addon_data.hunter.ResetShotTimer = function()
    -- The timer is reset to either the auto cast time or the difference between the time since the last shot and the current time depending on which is larger
    local curr_time = GetTime()
    local range_speed = addon_data.hunter.range_speed
	
    if (curr_time + 0.05 - addon_data.hunter.last_shot_time) > (range_speed - addon_data.hunter.auto_cast_time) then
		addon_data.hunter.shot_timer = addon_data.hunter.auto_cast_time
		addon_data.hunter.auto_shot_ready = true
		
    elseif curr_time ~= addon_data.hunter.last_shot_time and not addon_data.hunter.casting then
        addon_data.hunter.shot_timer = curr_time - addon_data.hunter.last_shot_time
        addon_data.hunter.auto_shot_ready = false
		
	elseif addon_data.hunter.casting then
		if (curr_time - addon_data.hunter.last_shot_time) > (3 * addon_data.hunter.range_cast_speed_modifer) then
			addon_data.hunter.shot_timer = addon_data.hunter.auto_cast_time
		end
    else
        addon_data.hunter.shot_timer = range_speed
        addon_data.hunter.auto_shot_ready = false
    end
end

addon_data.hunter.UpdateAutoShotTimer = function(elapsed)
    local curr_time = GetTime()
	local shot_timer = addon_data.hunter.shot_timer
	local _, class, _ = UnitClass("player")
    if addon_data.hunter.shot_timer < 0 then
		addon_data.hunter.shot_timer = 0
	else
		addon_data.hunter.shot_timer = shot_timer - elapsed
	end
	addon_data.hunter.auto_cast_time = 0.01
	addon_data.hunter.UpdateRangeCastSpeedModifier()
	
    -- If the player moved then the timer resets
    if addon_data.hunter.has_moved or addon_data.hunter.casting then
        if addon_data.hunter.shot_timer <= addon_data.hunter.auto_cast_time then
            addon_data.hunter.ResetShotTimer()			
        end
    end
    -- If the shot timer is less than the auto cast time then the auto shot is ready
    if addon_data.hunter.shot_timer <= addon_data.hunter.auto_cast_time then
        addon_data.hunter.auto_shot_ready = true
        -- If we are not shooting then the timer should be reset
        if not addon_data.hunter.shooting then
            addon_data.hunter.ResetShotTimer()
        end
    else
         addon_data.hunter.auto_shot_ready = false
    end
	if addon_data.hunter.spell_GCD_Time + 1.5 > curr_time then
		addon_data.hunter.spell_GCD = 1.5 - (curr_time - addon_data.hunter.spell_GCD_Time)
	end
end

addon_data.hunter.OnUpdate = function(elapsed)
    local settings = character_hunter_settings
    if not addon_data.hunter.IsRelevant() then
        addon_data.hunter.frame:Hide()
        return
    elseif settings.enabled and not addon_data.hunter.frame:IsShown() then
        addon_data.hunter.UpdateVisualsOnSettingsChange()
    end
    if settings.enabled then
        -- Check to see if we have moved
        addon_data.hunter.has_moved = (GetUnitSpeed("player") > 0)
		
		-- Check for feign death movement that causes swing reset
		if addon_data.hunter.FeignStatus and addon_data.hunter.has_moved then
			addon_data.hunter.FeignDeath()
			addon_data.hunter.FeignStatus = false
		end
		
        -- Update the Auto Shot timer based on the updated settings
        addon_data.hunter.UpdateAutoShotTimer(elapsed)
        -- Update the visuals
        addon_data.hunter.UpdateVisualsOnUpdate()
    end
end
-- detecting jumps out of a feign death to trigger a reset 
hooksecurefunc("JumpOrAscendStart", function()
	if  addon_data.hunter.FeignStatus then  
			addon_data.hunter.FeignDeath()
			addon_data.hunter.FeignStatus = false
	end	  
end)


--- spell functions to determine the state of the spell being casted.
--- -----------------------------------------------------------------
--- Determines the state of shooting on or off
addon_data.hunter.OnStartAutorepeatSpell = function()
    addon_data.hunter.shooting = true
	
    if addon_data.hunter.shot_timer <= addon_data.hunter.auto_cast_time then
        --addon_data.hunter.ResetShotTimer()
    end
end

addon_data.hunter.OnStopAutorepeatSpell = function()
    addon_data.hunter.shooting = false
end
-- Using combat log to detect pushback hits as well as starting to use spell cast events to replace the old version of detection that was implied
addon_data.hunter.OnCombatLogUnfiltered = function(combat_info)
    local _, event, _, casterID, _, _, _, _, _, _, _, spellID = unpack(combat_info)

	if casterID == UnitGUID("player") then
	
		if event == "SPELL_CAST_START" then
		
				addon_data.hunter.FeignStatus = false
				addon_data.hunter.StartCastingSpell(spellID)
				
				if addon_data.hunter.is_spell_auto_shot(spellID) then
					addon_data.hunter.casting_auto = true
				end
				if spellID == 34120 or addon_data.hunter.is_spell_multi_shot(spellID) then
					addon_data.hunter.spell_GCD = 1.5
					addon_data.hunter.spell_GCD_Time = GetTime()
				end
				
		return end

	end		
end

--- upon spell cast succeeded, check if is auto shot and reset timer, adjust ranged speed based on haste. 
--- If not auto shot, set bar to green *commented out
addon_data.hunter.OnUnitSpellCastSucceeded = function(unit, spell_id)

	if unit == 'player' then
	
	    addon_data.hunter.casting = false
        -- If the spell is Auto Shot then reset the shot timer
        if addon_data.hunter.shot_spell_ids[spell_id] then
            local spell_name = addon_data.hunter.shot_spell_ids[spell_id].spell_name
			if spell_name == L["Feign Death"] or spell_name == L["Trueshot Aura"] then
				if spell_name == L["Feign Death"] then
					addon_data.hunter.FeignStatus = true
				end
				addon_data.hunter.FeignDeath()
				return
			end
            if addon_data.hunter.is_spell_auto_shot(spell_id) or addon_data.hunter.is_spell_shoot(spell_id) then
				addon_data.hunter.FeignFullReset = false
                addon_data.hunter.last_shot_time = GetTime()
                addon_data.hunter.ResetShotTimer()
				addon_data.hunter.casting_auto = false
			--else 
                --addon_data.hunter.casting_auto = false
            end
			if addon_data.hunter.is_spell_shoot(spell_id) then
				local new_range_speed, _, _, _, _, _ = UnitRangedDamage("player")
				addon_data.hunter.range_speed = new_range_speed
			end
        end

		if addon_data.hunter.is_spell_auto_shot(spell_id) then	-- Update the ranged attack speed
			local new_range_speed, _, _, _, _, _ = UnitRangedDamage("player")

			-- Handling for getting haste buffs in combat, don't need to update auto shot cast time until the next shot is ready
			if new_range_speed ~= addon_data.hunter.range_speed then
				if not addon_data.hunter.auto_shot_ready then
					addon_data.hunter.shot_timer = addon_data.hunter.shot_timer * 
											(new_range_speed / addon_data.hunter.range_speed)
				end
                
				if not new_range_speed or new_range_speed == 0 then
                    new_range_speed = addon_data.hunter.range_speed or 1
                end
                addon_data.hunter.range_speed = new_range_speed
				addon_data.hunter.range_auto_speed_modified = addon_data.hunter.range_cast_speed_modifer
			end
		end
    end
end

addon_data.hunter.OnUnitSpellCastInterrupted = function(unit, spell_id)
	
	addon_data.hunter.casting = false
	if unit == 'player' and addon_data.hunter.is_spell_auto_shot(spell_id) then
		addon_data.hunter.casting_auto = false
		--addon_data.hunter.shot_timer = addon_data.hunter.auto_cast_time
		--addon_data.hunter.ResetShotTimer()
	end
	
end

--- triggered when auto shot is toggled on and attempts to begin casting, but can't
--- This causes 0.5 seconds of delay before it can try casting again
addon_data.hunter.OnUnitSpellCastFailedQuiet = function(unit, spell_id)
    local settings = character_hunter_settings
	local curr_time = GetTime()
    if settings.show_autoshot_delay_timer and unit == "player" and addon_data.hunter.is_spell_auto_shot(spell_id) then
        
		if not addon_data.hunter.casting and addon_data.hunter.shooting 
		   and (curr_time - addon_data.hunter.last_shot_time) > (addon_data.hunter.range_speed - addon_data.hunter.auto_cast_time) then
			
			addon_data.hunter.shot_timer = addon_data.hunter.auto_cast_time + 0.5
		end
    end
end

--- Updating and initializing visuals
--- ---------------------------------
addon_data.hunter.UpdateVisualsOnUpdate = function()
    local settings = character_hunter_settings
    local frame = addon_data.hunter.frame
    local range_speed = addon_data.hunter.range_speed
    local shot_timer = addon_data.hunter.shot_timer
    local new_width = 0
	
	if settings.enabled then
        frame.shot_bar_text:SetText(addon_data.utils.FormatTime(shot_timer))
        if addon_data.core.in_combat or addon_data.hunter.shooting or addon_data.hunter.casting_shot then
            frame:SetAlpha(settings.in_combat_alpha)
        else
            frame:SetAlpha(settings.ooc_alpha)
        end
        if not settings.one_bar then
                if addon_data.hunter.spell_GCD > 0.5 then
					frame.shot_bar:SetVertexColor(0.7, 0.4, 0, 1)
				else
					frame.shot_bar:SetVertexColor(settings.cooldown_r, settings.cooldown_g, settings.cooldown_b, settings.cooldown_a)
				end
                new_width = settings.width * (shot_timer / range_speed)
            -- empty when ready (no 2px line in the middle)
            if new_width < 1 then
                frame.shot_bar:Hide()
            else
                frame.shot_bar:Show()
                frame.shot_bar:SetWidth(math.min(new_width, settings.width))
            end
        else
		    if addon_data.hunter.spell_GCD > 0.2 then
				frame.shot_bar:SetVertexColor(0.7, 0.4, 0, 1)
			else
				frame.shot_bar:SetVertexColor(settings.cooldown_r, settings.cooldown_g, settings.cooldown_b, settings.cooldown_a)
			end
            timer_width = settings.width * ((addon_data.hunter.range_speed - addon_data.hunter.shot_timer) / addon_data.hunter.range_speed)
            frame.shot_bar:SetWidth(math.min(timer_width, settings.width))
        end
		frame:SetSize(settings.width, settings.height)
    end
end

addon_data.hunter.UpdateVisualsOnSettingsChange = function()
    local settings = character_hunter_settings
    local frame = addon_data.hunter.frame
	if settings.enabled and addon_data.hunter.IsRelevant() then
        frame:EnableMouse(not settings.is_locked)
        frame:Show()
        frame:ClearAllPoints()
        frame:SetPoint(settings.point, UIParent, settings.rel_point, settings.x_offset, settings.y_offset)
        addon_data.compat.ApplyBackplane(frame.backplane, settings.show_border, settings.backplane_alpha)
        frame.shot_bar:ClearAllPoints()
        if not settings.one_bar then
            frame.shot_bar:SetPoint("BOTTOM", 0, 0)
        else
            frame.shot_bar:SetPoint("BOTTOMLEFT", 0, 0)
            frame.shot_bar:SetVertexColor(settings.cooldown_r, settings.cooldown_g, settings.cooldown_b, settings.cooldown_a)
        end
        frame.shot_bar_text:SetPoint("BOTTOMRIGHT", -5, (settings.height / 2) - (settings.fontsize / 2))
        frame.shot_bar_text:SetTextColor(1.0, 1.0, 1.0, 1.0)
		frame.shot_bar_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
		
        frame.shot_bar:SetHeight(settings.height)
        if settings.classic_bars then
            frame.shot_bar:SetTexture(addon_data.GetBarTexture())
        else
            frame.shot_bar:SetTexture(addon_data.media .. "Background")
        end
        if settings.show_text then
            frame.shot_bar_text:Show()
        else
            frame.shot_bar_text:Hide()
        end
    else
        frame:Hide()
    end
end

addon_data.hunter.OnFrameDragStart = function()
    if not character_hunter_settings.is_locked then
        addon_data.hunter.frame:StartMoving()
    end
end

addon_data.hunter.OnFrameDragStop = function()
    local frame = addon_data.hunter.frame
    local settings = character_hunter_settings
    frame:StopMovingOrSizing()
    local point, _, rel_point, x_offset, y_offset = frame:GetPoint()
    if x_offset < 20 and x_offset > -20 then
        x_offset = 0
    end
    settings.point = point
    settings.rel_point = rel_point
    settings.x_offset = addon_data.utils.SimpleRound(x_offset, 1)
    settings.y_offset = addon_data.utils.SimpleRound(y_offset, 1)
    addon_data.hunter.UpdateVisualsOnSettingsChange()
    addon_data.hunter.UpdateConfigPanelValues()
end

addon_data.hunter.InitializeVisuals = function()
    local settings = character_hunter_settings
    -- Create the frame
    addon_data.hunter.frame = CreateFrame("Frame", addon_name .. "HunterAutoshotFrame", UIParent)
    local frame = addon_data.hunter.frame
	
    frame:SetMovable(true)
    frame:EnableMouse(not settings.is_locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", addon_data.hunter.OnFrameDragStart)
    frame:SetScript("OnDragStop", addon_data.hunter.OnFrameDragStop)
    -- Create the backplane
    frame.backplane = CreateFrame("Frame", addon_name .. "HunterBackdropFrame", frame, addon_data.compat.BackdropTemplate)
    frame.backplane:SetPoint('TOPLEFT', -9, 9)
    frame.backplane:SetPoint('BOTTOMRIGHT', 9, -9)
    frame.backplane:SetFrameStrata('BACKGROUND')
    -- Create the shot bar
    frame.shot_bar = frame:CreateTexture(nil,"ARTWORK")
    -- Create the shot bar text
    frame.shot_bar_text = frame:CreateFontString(nil,"OVERLAY")
    frame.shot_bar_text:SetFont(addon_data.GetBarFont(), settings.fontsize)
    frame.shot_bar_text:SetJustifyV("MIDDLE")
    frame.shot_bar_text:SetJustifyH("CENTER")
    -- Show it off
    addon_data.hunter.UpdateVisualsOnSettingsChange()
    addon_data.hunter.UpdateVisualsOnUpdate()
    frame:Show()
end
