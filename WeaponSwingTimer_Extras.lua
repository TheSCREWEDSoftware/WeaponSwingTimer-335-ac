-- Optional features (all off by default). Wraps the bar modules instead of editing them.
local addon_name, addon_data = ...
local L = addon_data.localization_table

local extras = {}
addon_data.extras = extras

local function T(text) return (L and L[text]) or text end

extras.default_settings = {
    font = "default",
    timer_decimals = 1,
    stack_bars = true,
    stack_gap = 20,
    stack_init = false,
    stack_x = 0,
    stack_y = -276,
    bar_texture = "default",
    border = "default",
    vertical = false,
    queued_color = false,
    queued_r = 1.0, queued_g = 0.6, queued_b = 0.0, queued_a = 1.0,
    deadzone = false,
    leading_deadzone = 0.0,
    trailing_deadzone = 0.0,
    deadzone_r = 1.0, deadzone_g = 0.4, deadzone_b = 0.0, deadzone_a = 1.0,
    slam_marker = false,
    slam_r = 1.0, slam_g = 1.0, slam_b = 1.0, slam_a = 0.9,
    hl_player_main = false, hl_player_main_r = 1.0, hl_player_main_g = 1.0, hl_player_main_b = 1.0, hl_player_main_a = 0.35,
    hl_player_off = false,  hl_player_off_r = 1.0,  hl_player_off_g = 1.0,  hl_player_off_b = 1.0,  hl_player_off_a = 0.35,
    hl_target_main = false, hl_target_main_r = 1.0, hl_target_main_g = 1.0, hl_target_main_b = 1.0, hl_target_main_a = 0.35,
    hl_target_off = false,  hl_target_off_r = 1.0,  hl_target_off_g = 1.0,  hl_target_off_b = 1.0,  hl_target_off_a = 0.35,
    haste_color = false,
    haste_r = 0.2, haste_g = 0.9, haste_b = 0.2, haste_a = 1.0,
    cast_reset = false,
}

local function S() return character_extras_settings or extras.default_settings end

extras.LoadSettings = function()
    character_extras_settings = addon_data.db.profile.extras
    for setting, value in pairs(extras.default_settings) do
        if character_extras_settings[setting] == nil then
            character_extras_settings[setting] = value
        end
    end
    -- one-time (per account): untick highlights an earlier build ticked, drop old keys
    local global = addon_data.db.global
    if not global.hl_reset_v1 then
        character_extras_settings.hl_player_main = false
        character_extras_settings.hl_player_off = false
        character_extras_settings.hl_target_main = false
        character_extras_settings.hl_target_off = false
        global.hl_reset_v1 = true
    end
    character_extras_settings.swing_flash = nil
    character_extras_settings.hl_reset_v1 = nil
end

-- Media: fonts, bar textures, borders
extras.media = {
    font = {
        { key = "default",  name = "Friz Quadrata (default)", path = "Fonts\\FRIZQT__.TTF" },
        { key = "arialn",   name = "Arial Narrow",            path = "Fonts\\ARIALN.TTF" },
        { key = "skurri",   name = "Skurri",                  path = "Fonts\\skurri.ttf" },
        { key = "morpheus", name = "Morpheus",                path = "Fonts\\MORPHEUS.ttf" },
    },
    bar_texture = {
        { key = "default",  name = "WeaponSwingTimer (default)", path = addon_data.media .. "Bar" },
        { key = "blizzard", name = "Blizzard",                   path = "Interface\\TargetingFrame\\UI-StatusBar" },
        { key = "raid",     name = "Raid",                       path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
        { key = "flat",     name = "Flat",                       path = "Interface\\Buttons\\WHITE8X8" },
    },
    border = {
        { key = "default",  name = "WeaponSwingTimer (default)", path = addon_data.media .. "Border", size = 12 },
        { key = "tooltip",  name = "Tooltip",                    path = "Interface\\Tooltips\\UI-Tooltip-Border", size = 16 },
        { key = "dialog",   name = "Dialog",                     path = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 16 },
    },
}

local lsm_types = { font = "font", bar_texture = "statusbar", border = "border" }

-- Built-in media plus LibSharedMedia entries, if another addon loaded it
local function MediaList(kind)
    local list = {}
    for _, entry in ipairs(extras.media[kind]) do list[#list + 1] = entry end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local names = LSM:List(lsm_types[kind]) or {}
        for _, name in ipairs(names) do
            list[#list + 1] = { key = "lsm:" .. name, name = name .. " (SharedMedia)",
                                lsm = name, size = (kind == "border") and 16 or nil }
        end
    end
    return list
end
extras.MediaList = MediaList

local function FindMedia(kind, key)
    if key and key:sub(1, 4) == "lsm:" then
        local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
        local path = LSM and LSM:Fetch(lsm_types[kind], key:sub(5), true)
        if path then return { key = key, name = key:sub(5), path = path, size = 16 } end
    end
    for _, entry in ipairs(extras.media[kind]) do
        if entry.key == key then return entry end
    end
    return extras.media[kind][1]
end

-- Used by the bar modules when drawing
addon_data.GetBarFont = function() return FindMedia("font", S().font).path end
addon_data.GetBarTexture = function() return FindMedia("bar_texture", S().bar_texture).path end
addon_data.GetBorderInfo = function()
    local entry = FindMedia("border", S().border)
    return entry.path, entry.size or 12
end

-- State
-- When each bar last started a swing (for the background highlight)
extras.swing_started = { player_main = 0, player_off = 0, target_main = 0, target_off = 0 }
extras.HIGHLIGHT_TIME = 0.2
extras.main_hasted = false
extras.off_hasted = false

-- Next-swing abilities (client names, so any language works)
local queued_names = {}
for _, id in ipairs({ 78, 845, 6807, 2973, 56815 }) do
    local name = GetSpellInfo(id)
    if name then queued_names[#queued_names + 1] = name end
end
local slam_name = GetSpellInfo(1464)

local function IsNextSwingQueued()
    if not IsCurrentSpell then return false end
    for _, name in ipairs(queued_names) do
        if IsCurrentSpell(name) then return true end
    end
    return false
end

-- Helpers
local function FillFraction(timer, speed, fill_empty)
    if not speed or speed == 0 then speed = 2 end
    local frac = 1 - (timer / speed)
    if frac > 1 then frac = 1 elseif frac < 0 then frac = 0 end
    if not fill_empty then frac = 1 - frac end
    return frac
end

local function EnsureTexture(frame, key, layer)
    if not frame[key] then
        frame[key] = frame:CreateTexture(nil, layer or "OVERLAY")
    end
    return frame[key]
end

-- Turn the spark 90 degrees for vertical bars
local function SetSparkRotated(spark, rotated)
    if rotated then
        spark:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    else
        spark:SetTexCoord(0, 1, 0, 1)
    end
end

-- Undo vertical anchoring before the original code lays the bar out
local function ClearVerticalLayout(frame, regions)
    if not frame.wst_vertical then return end
    for _, key in ipairs(regions) do
        if frame[key] then frame[key]:ClearAllPoints() end
    end
    if frame.main_spark then SetSparkRotated(frame.main_spark, false) end
    if frame.off_spark then SetSparkRotated(frame.off_spark, false) end
    frame.wst_vertical = false
end

local melee_regions = {
    "main_bar", "off_bar", "main_spark", "off_spark",
    "main_left_text", "main_right_text", "off_left_text", "off_right_text",
    "wst_slam_marker",
}

-- Vertical layout (applied after the original horizontal layout)
local function ApplyVertical(unit_data, settings)
    local frame = unit_data.frame
    local two = unit_data.has_offhand and settings.show_offhand
    local thick = settings.height
    local len = settings.width
    frame.wst_vertical = true
    frame:SetWidth(two and (thick * 2 + 2) or thick)
    frame:SetHeight(len)

    local main_frac = FillFraction(unit_data.main_swing_timer, unit_data.main_weapon_speed, settings.fill_empty)
    frame.main_bar:ClearAllPoints()
    frame.main_bar:SetPoint("BOTTOMLEFT", 0, 0)
    frame.main_bar:SetWidth(thick)
    frame.main_bar:SetHeight(math.max(len * main_frac, 0.001))
    frame.main_spark:ClearAllPoints()
    frame.main_spark:SetSize(thick, 16)
    frame.main_spark:SetPoint("BOTTOMLEFT", 0, len * main_frac - 8)
    SetSparkRotated(frame.main_spark, true)
    if main_frac >= 1 or main_frac <= 0.001 or not settings.classic_bars then
        frame.main_spark:Hide()
    end

    -- Text can't rotate on 3.3.5: timers above each column, labels hidden
    frame.main_left_text:Hide()
    frame.main_right_text:ClearAllPoints()
    frame.main_right_text:SetPoint("BOTTOM", frame.main_bar, "BOTTOM", 0, len + 2)
    frame.off_left_text:Hide()

    if two then
        local off_frac = FillFraction(unit_data.off_swing_timer, unit_data.off_weapon_speed, settings.fill_empty)
        frame.off_bar:ClearAllPoints()
        frame.off_bar:SetPoint("BOTTOMRIGHT", 0, 0)
        frame.off_bar:SetWidth(thick)
        frame.off_bar:SetHeight(math.max(len * off_frac, 0.001))
        frame.off_spark:ClearAllPoints()
        frame.off_spark:SetSize(thick, 16)
        frame.off_spark:SetPoint("BOTTOMRIGHT", 0, len * off_frac - 8)
        SetSparkRotated(frame.off_spark, true)
        if off_frac >= 1 or off_frac <= 0.001 or not settings.classic_bars then
            frame.off_spark:Hide()
        end
        frame.off_right_text:ClearAllPoints()
        frame.off_right_text:SetPoint("BOTTOM", frame.off_bar, "BOTTOM", 0, len + 2)
    end

end

-- After each player / target update
local function AfterMeleeUpdate(unit_data, settings, is_player)
    local frame = unit_data.frame
    if not frame or not settings.enabled then return end
    local ex = S()

    if ex.vertical then
        ApplyVertical(unit_data, settings)
    end

    -- New swing: brief background colour behind the fill, per bar (no fade)
    local who = is_player and "player" or "target"
    for _, hand in ipairs({ "main", "off" }) do
        local key = "hl_" .. who .. "_" .. hand
        local bg = EnsureTexture(frame, "wst_hl_" .. hand, "BORDER")
        local bar_visible = (hand == "main") or (unit_data.has_offhand and settings.show_offhand)
        local since = GetTime() - extras.swing_started[who .. "_" .. hand]
        if ex[key] and bar_visible and since < extras.HIGHLIGHT_TIME then
            addon_data.compat.SetColorTexture(bg, ex[key .. "_r"], ex[key .. "_g"], ex[key .. "_b"], ex[key .. "_a"])
            bg:ClearAllPoints()
            if ex.vertical then
                bg:SetPoint((hand == "main") and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)
                bg:SetSize(settings.height, settings.width)
            else
                bg:SetPoint((hand == "main") and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
                bg:SetSize(settings.width, settings.height)
            end
            bg:Show()
        else
            bg:Hide()
        end
    end

    if is_player then
        -- Bar colour: queued > dead zone > haste > normal
        if ex.queued_color or ex.deadzone or ex.haste_color then
            local r, g, b, a = settings.main_r, settings.main_g, settings.main_b, settings.main_a
            local speed = unit_data.main_weapon_speed
            local timer = unit_data.main_swing_timer
            local in_deadzone = false
            if ex.deadzone then
                -- maldon's dead-zone logic (LeftHandedGlove PR #22)
                local leading = tonumber(ex.leading_deadzone) or 0
                local trailing = tonumber(ex.trailing_deadzone) or 0
                if speed > leading + trailing and (leading > 0 or trailing > 0) then
                    if (leading > 0 and timer >= speed - leading) or (trailing > 0 and timer <= trailing and timer > 0) then
                        in_deadzone = true
                    end
                end
            end
            if ex.queued_color and IsNextSwingQueued() then
                r, g, b, a = ex.queued_r, ex.queued_g, ex.queued_b, ex.queued_a
            elseif in_deadzone then
                r, g, b, a = ex.deadzone_r, ex.deadzone_g, ex.deadzone_b, ex.deadzone_a
            elseif ex.haste_color and extras.main_hasted then
                r, g, b, a = ex.haste_r, ex.haste_g, ex.haste_b, ex.haste_a
            end
            frame.main_bar:SetVertexColor(r, g, b, a)
            if ex.haste_color then
                if extras.off_hasted then
                    frame.off_bar:SetVertexColor(ex.haste_r, ex.haste_g, ex.haste_b, ex.haste_a)
                else
                    frame.off_bar:SetVertexColor(settings.off_r, settings.off_g, settings.off_b, settings.off_a)
                end
            end
        end

        -- Haste changed while a swing was running (Flurry, haste procs)
        if ex.haste_color then
            if unit_data.main_speed_changed and unit_data.main_swing_timer > 0 then extras.main_hasted = true end
            if unit_data.off_speed_changed and unit_data.off_swing_timer > 0 then extras.off_hasted = true end
        end

        -- Slam marker: casting Slam after this point delays the next swing
        local marker = EnsureTexture(frame, "wst_slam_marker", "OVERLAY")
        local _, class = UnitClass("player")
        local slam_cast = nil
        if ex.slam_marker and class == "WARRIOR" and slam_name then
            local _, _, _, cast_ms = addon_data.compat.GetSpellInfo(slam_name)
            if cast_ms and cast_ms > 0 then slam_cast = cast_ms / 1000 end
        end
        if slam_cast and unit_data.main_weapon_speed > slam_cast then
            local frac = FillFraction(slam_cast, unit_data.main_weapon_speed, settings.fill_empty)
            addon_data.compat.SetColorTexture(marker, ex.slam_r, ex.slam_g, ex.slam_b, ex.slam_a)
            marker:ClearAllPoints()
            if ex.vertical then
                marker:SetSize(settings.height, 2)
                marker:SetPoint("BOTTOMLEFT", 0, frac * settings.width)
            else
                marker:SetSize(2, settings.height)
                marker:SetPoint("TOPLEFT", frac * settings.width, 0)
            end
            marker:Show()
        else
            marker:Hide()
        end

    end
end

-- Wrap the original update functions
extras.Install = function()
    if extras.installed then return end
    extras.installed = true
    local player, target = addon_data.player, addon_data.target

    local orig_player_update = player.UpdateVisualsOnUpdate
    player.UpdateVisualsOnUpdate = function(...)
        orig_player_update(...)
        AfterMeleeUpdate(player, character_player_settings, true)
    end
    local orig_target_update = target.UpdateVisualsOnUpdate
    target.UpdateVisualsOnUpdate = function(...)
        orig_target_update(...)
        if UnitExists("target") then
            AfterMeleeUpdate(target, character_target_settings, false)
        end
    end
    local orig_player_settings = player.UpdateVisualsOnSettingsChange
    player.UpdateVisualsOnSettingsChange = function(...)
        if player.frame then ClearVerticalLayout(player.frame, melee_regions) end
        orig_player_settings(...)
    end
    local orig_target_settings = target.UpdateVisualsOnSettingsChange
    target.UpdateVisualsOnSettingsChange = function(...)
        if target.frame then ClearVerticalLayout(target.frame, melee_regions) end
        orig_target_settings(...)
    end

    local orig_reset_main = player.ResetMainSwingTimer
    player.ResetMainSwingTimer = function(...)
        extras.swing_started.player_main = GetTime()
        extras.main_hasted = false
        return orig_reset_main(...)
    end
    local orig_reset_off = player.ResetOffSwingTimer
    player.ResetOffSwingTimer = function(...)
        if player.has_offhand then extras.swing_started.player_off = GetTime() end
        extras.off_hasted = false
        return orig_reset_off(...)
    end
    local orig_target_main = target.ResetMainSwingTimer
    target.ResetMainSwingTimer = function(...)
        if UnitExists("target") then extras.swing_started.target_main = GetTime() end
        return orig_target_main(...)
    end
    local orig_target_off = target.ResetOffSwingTimer
    target.ResetOffSwingTimer = function(...)
        if target.has_offhand and UnitExists("target") then extras.swing_started.target_off = GetTime() end
        return orig_target_off(...)
    end
end
extras.Install()

-- Reset the swing after a spell cast (experimental, LeftHandedGlove #19)
local cast_frame = CreateFrame("Frame")
cast_frame:RegisterEvent("UNIT_SPELLCAST_START")
cast_frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
cast_frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
cast_frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
cast_frame:SetScript("OnEvent", function(self, event, unit, spell)
    if unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_START" then
        extras.cast_in_progress = spell
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local was_cast = extras.cast_in_progress
        extras.cast_in_progress = nil
        if was_cast and S().cast_reset and was_cast ~= slam_name then
            -- set directly so it doesn't count as a swing
            local p = addon_data.player
            p.main_swing_timer = p.main_weapon_speed
            if p.has_offhand then p.off_swing_timer = p.off_weapon_speed end
        end
    else
        extras.cast_in_progress = nil
    end
end)

-- Stack: bottom to top Ranged, Spell cast, Target, Self; hidden bars collapse
local function StackFrames()
    return { addon_data.hunter.frame, addon_data.castbar.frame, addon_data.target.frame, addon_data.player.frame }
end

-- First use: start the stack where the shot bar sits now
local function InitStack(ex)
    local hs = character_hunter_settings
    if hs and hs.point == "CENTER" and hs.rel_point == "CENTER" then
        ex.stack_x = hs.x_offset or 0
        ex.stack_y = (hs.y_offset or -260) - (hs.height or 12) / 2
    end
    ex.stack_init = true
end

extras.Stack = function()
    local ex = S()
    if not ex.stack_bars or ex.vertical or extras.stack_dragging then return end
    if not ex.stack_init then InitStack(ex) end
    local y = ex.stack_y
    for _, frame in ipairs(StackFrames()) do
        if frame and frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOM", UIParent, "CENTER", ex.stack_x, y)
            y = y + (frame:GetHeight() or 0) + ex.stack_gap
        end
    end
end

-- Dragging any bar moves the whole stack
local function OnStackDragStop(dropped)
    extras.stack_dragging = false
    local ex = S()
    if not ex.stack_bars or ex.vertical then return end
    local below = 0
    for _, frame in ipairs(StackFrames()) do
        if frame == dropped then break end
        if frame and frame:IsShown() then below = below + (frame:GetHeight() or 0) + ex.stack_gap end
    end
    local cx = dropped:GetCenter()
    local bottom = dropped:GetBottom()
    if cx and bottom then
        ex.stack_x = math.floor(cx - UIParent:GetWidth() / 2 + 0.5)
        ex.stack_y = math.floor(bottom - UIParent:GetHeight() / 2 - below + 0.5)
        ex.stack_init = true
    end
end

extras.HookStackDragging = function()
    for _, frame in ipairs(StackFrames()) do
        frame:HookScript("OnDragStart", function() extras.stack_dragging = true end)
        frame:HookScript("OnDragStop", function(self) OnStackDragStop(self) end)
    end
end

-- API for macros and other addons (LeftHandedGlove #13)
function WeaponSwingTimer_GetSwing(unit, hand)
    local data = (unit == "target") and addon_data.target or addon_data.player
    if hand == "off" then
        if not data.has_offhand then return nil end
        return data.off_swing_timer, data.off_weapon_speed
    end
    return data.main_swing_timer, data.main_weapon_speed
end
