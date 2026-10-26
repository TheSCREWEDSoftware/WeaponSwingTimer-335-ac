--[[
    WeaponSwingTimer-335-ac : Extras
    Opt-in features requested on the original projects' issue trackers. Everything here is OFF by
    default, so with default settings the bars look and behave exactly like the backport.

    - Colour while Heroic Strike / Cleave / Maul / Raptor Strike / Rune Strike is queued  (SixxFix #11)
    - Leading / trailing dead-zone colouring    (SixxFix #21; logic from maldon, LeftHandedGlove PR #22)
    - Slam marker                               (SixxFix #12)
    - Flash when a swing lands                  (SixxFix #19)
    - Colour when attack speed changes mid-swing(LeftHandedGlove #18)
    - Vertical bars                             (SixxFix #18)
    - Font / bar texture / border choice        (SixxFix #14, #5)
    - WeaponSwingTimer_GetSwing() for macros     (LeftHandedGlove #13)
    - Reset the swing after a cast (experimental)(LeftHandedGlove #19)

    The original modules are not edited for these: their update functions are wrapped, and the
    extras are applied after the original drawing code has run.
]]
local addon_name, addon_data = ...
local L = addon_data.localization_table

local extras = {}
addon_data.extras = extras

local function T(text) return (L and L[text]) or text end

extras.default_settings = {
    font = "default",
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
    swing_flash = false,
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
end

--[[------------------------------------------------------------------------------------------
    Media: fonts, bar textures and borders (built-in; plus LibSharedMedia if another addon has it)
--------------------------------------------------------------------------------------------]]
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

-- Adds LibSharedMedia entries (if another addon loaded the library) to a media list.
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

-- Used by the bar modules at draw time (this file loads after them, before Config/Core)
addon_data.GetBarFont = function() return FindMedia("font", S().font).path end
addon_data.GetBarTexture = function() return FindMedia("bar_texture", S().bar_texture).path end
addon_data.GetBorderInfo = function()
    local entry = FindMedia("border", S().border)
    return entry.path, entry.size or 12
end

--[[------------------------------------------------------------------------------------------
    State
--------------------------------------------------------------------------------------------]]
extras.flash_time = 0
extras.flash_off_time = 0
extras.main_hasted = false
extras.off_hasted = false

-- Next-swing abilities whose queued state colours the main-hand bar (names come from the client,
-- so they match any language)
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

--[[------------------------------------------------------------------------------------------
    Helpers
--------------------------------------------------------------------------------------------]]
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

-- Spark is a vertical glow line; for vertical bars it is turned 90 degrees.
local function SetSparkRotated(spark, rotated)
    if rotated then
        spark:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
    else
        spark:SetTexCoord(0, 1, 0, 1)
    end
end

-- Puts a bar back into the original horizontal anchoring before the original code re-anchors it
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
    "pala_blood_marker", "pala_command_marker", "wst_slam_marker",
}

--[[------------------------------------------------------------------------------------------
    Vertical layout (applied after the original update has positioned everything horizontally)
--------------------------------------------------------------------------------------------]]
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

    -- Text does not rotate on 3.3.5: show the timers above each column, hide the labels
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

    -- Paladin markers: the original code put them at an x offset along the bar
    for _, key in ipairs({ "pala_blood_marker", "pala_command_marker" }) do
        local marker = frame[key]
        if marker and marker:IsShown() then
            local _, _, _, x = marker:GetPoint(1)
            local offset = settings.pala_offset or 0
            marker:ClearAllPoints()
            marker:SetSize(frame:GetWidth() + 2 * offset, 1)
            marker:SetPoint("BOTTOMLEFT", -offset, (x or 0) / settings.width * len)
        end
    end
end

--[[------------------------------------------------------------------------------------------
    After each player / target update
--------------------------------------------------------------------------------------------]]
local function AfterMeleeUpdate(unit_data, settings, is_player)
    local frame = unit_data.frame
    if not frame or not settings.enabled then return end
    local ex = S()

    if ex.vertical then
        ApplyVertical(unit_data, settings)
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

        -- Flash the bar that just swung: a brief highlight on that bar only, shown and hidden
        -- in one step (no fade)
        for _, hand in ipairs({ "main", "off" }) do
            local flash = EnsureTexture(frame, "wst_flash_" .. hand, "OVERLAY")
            if not flash.wst_ready then
                addon_data.compat.SetColorTexture(flash, 1, 1, 1, 0.25)
                flash:SetBlendMode("ADD")
                flash.wst_ready = true
            end
            local bar_visible = (hand == "main") or (unit_data.has_offhand and settings.show_offhand)
            local since = GetTime() - ((hand == "main") and extras.flash_time or extras.flash_off_time)
            if ex.swing_flash and bar_visible and since < 0.15 then
                flash:ClearAllPoints()
                if ex.vertical then
                    flash:SetPoint((hand == "main") and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, 0)
                    flash:SetSize(settings.height, settings.width)
                else
                    flash:SetPoint((hand == "main") and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
                    flash:SetSize(settings.width, settings.height)
                end
                flash:Show()
            else
                flash:Hide()
            end
        end
    end
end

--[[------------------------------------------------------------------------------------------
    Wrap the original update functions (applied once the modules exist)
--------------------------------------------------------------------------------------------]]
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
        extras.flash_time = GetTime()
        extras.main_hasted = false
        return orig_reset_main(...)
    end
    local orig_reset_off = player.ResetOffSwingTimer
    player.ResetOffSwingTimer = function(...)
        extras.flash_off_time = GetTime()
        extras.off_hasted = false
        return orig_reset_off(...)
    end
end
extras.Install()

--[[------------------------------------------------------------------------------------------
    Reset the swing after a spell cast (experimental, LeftHandedGlove #19)
--------------------------------------------------------------------------------------------]]
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
            -- set directly (not via the Reset functions) so it does not count as a swing
            local p = addon_data.player
            p.main_swing_timer = p.main_weapon_speed
            if p.has_offhand then p.off_swing_timer = p.off_weapon_speed end
        end
    else
        extras.cast_in_progress = nil
    end
end)

--[[------------------------------------------------------------------------------------------
    API for macros and other addons (LeftHandedGlove #13)
    /run print(WeaponSwingTimer_GetSwing("player"))
    returns: seconds until the next swing, weapon speed
--------------------------------------------------------------------------------------------]]
function WeaponSwingTimer_GetSwing(unit, hand)
    local data = (unit == "target") and addon_data.target or addon_data.player
    if hand == "off" then
        if not data.has_offhand then return nil end
        return data.off_swing_timer, data.off_weapon_speed
    end
    return data.main_swing_timer, data.main_weapon_speed
end

--[[------------------------------------------------------------------------------------------
    Options page
--------------------------------------------------------------------------------------------]]
local function MediaDropDown(panel, g_name, kind, label, x, y)
    local title = addon_data.config.TextFactory(panel, label, 12)
    title:SetPoint("TOPLEFT", x + 18, y)
    local dropdown = CreateFrame("Frame", addon_name .. g_name, panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", x, y - 14)
    UIDropDownMenu_SetWidth(dropdown, 150)
    local function Refresh()
        UIDropDownMenu_SetText(dropdown, FindMedia(kind, S()[kind]).name)
    end
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, entry in ipairs(MediaList(kind)) do
            info.text = entry.name
            info.value = entry.key
            info.checked = (S()[kind] == entry.key)
            info.func = function(button)
                character_extras_settings[kind] = button.value
                Refresh()
                addon_data.core.UpdateAllVisualsOnSettingsChange()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    dropdown.Refresh = Refresh
    Refresh()
    return dropdown
end

local function Toggle(panel, g_name, key, label, tooltip, x, y)
    local checkbox = addon_data.config.CheckBoxFactory(g_name, panel, label, tooltip, function(self)
        character_extras_settings[key] = self:GetChecked() and true or false
        addon_data.core.UpdateAllVisualsOnSettingsChange()
    end)
    -- CheckBoxFactory scales checkboxes by 1.1; divide so x/y are real pixels like other widgets
    checkbox:SetPoint("TOPLEFT", x / 1.1, y / 1.1)
    checkbox.wst_key = key
    return checkbox
end

local function ColorButton(panel, g_name, key, label, x, y)
    local ex = S()
    local picker
    picker = addon_data.config.color_picker_factory(g_name, panel,
        ex[key .. "_r"], ex[key .. "_g"], ex[key .. "_b"], ex[key .. "_a"], label,
        function()
            addon_data.config.ShowColorPicker(character_extras_settings, key, picker.foreground,
                addon_data.core.UpdateAllVisualsOnSettingsChange)
        end)
    picker:SetPoint("TOPLEFT", x, y)
    picker.wst_key = key
    return picker
end

extras.CreateConfigPanel = function(panel)
    panel.toggles, panel.colors = {}, {}
    local function add_toggle(...) local c = Toggle(...) table.insert(panel.toggles, c) return c end
    local function add_color(...) local c = ColorButton(...) table.insert(panel.colors, c) return c end

    local title = addon_data.config.TextFactory(panel, T("Extras"), 20)
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetTextColor(1, 0.82, 0, 1)
    local note = addon_data.config.TextFactory(panel, T("Optional features. Everything here is off by default."), 12)
    note:SetPoint("TOPLEFT", 10, -36)

    -- Layout (real pixels). Checkbox rows are 26px apart; colour swatches sit on the same row.
    local ROW = 26
    local SWATCH_X = 420
    local function swatch_y(row_y) return row_y - 7 end

    -- Appearance
    local appearance = addon_data.config.TextFactory(panel, T("Appearance (all bars)"), 16)
    appearance:SetPoint("TOPLEFT", 10, -62)
    appearance:SetTextColor(1, 0.82, 0, 1)
    panel.font_dropdown = MediaDropDown(panel, "ExtrasFontDropDown", "font", T("Font"), 0, -84)
    panel.texture_dropdown = MediaDropDown(panel, "ExtrasTextureDropDown", "bar_texture", T("Bar texture"), 195, -84)
    panel.border_dropdown = MediaDropDown(panel, "ExtrasBorderDropDown", "border", T("Border"), 390, -84)
    add_toggle(panel, "ExtrasVerticalCheckBox", "vertical", T("Vertical bars"),
        T("Player and target bars fill from bottom to top."), 10, -136)

    -- Player swing bar
    local player = addon_data.config.TextFactory(panel, T("Player swing bar"), 16)
    player:SetPoint("TOPLEFT", 10, -172)
    player:SetTextColor(1, 0.82, 0, 1)
    local y = -194
    add_toggle(panel, "ExtrasQueuedCheckBox", "queued_color", T("Colour while a next-swing ability is queued"),
        T("Heroic Strike, Cleave, Maul, Raptor Strike or Rune Strike."), 10, y)
    add_color(panel, "ExtrasQueuedColor", "queued", T("Queued colour"), SWATCH_X, swatch_y(y))
    y = y - ROW
    add_toggle(panel, "ExtrasHasteCheckBox", "haste_color", T("Colour when attack speed changes mid-swing"),
        T("For example a Flurry proc. Lasts until the next swing."), 10, y)
    add_color(panel, "ExtrasHasteColor", "haste", T("Haste colour"), SWATCH_X, swatch_y(y))
    y = y - ROW
    add_toggle(panel, "ExtrasSlamCheckBox", "slam_marker", T("Slam marker (Warriors)"),
        T("Casting Slam after this marker delays your next swing."), 10, y)
    add_color(panel, "ExtrasSlamColor", "slam", T("Marker colour"), SWATCH_X, swatch_y(y))
    y = y - ROW
    add_toggle(panel, "ExtrasFlashCheckBox", "swing_flash", T("Flash the bar when a swing lands"),
        T("A brief white highlight on the bar that just swung (main or off hand)."), 10, y)
    y = y - ROW
    add_toggle(panel, "ExtrasDeadzoneCheckBox", "deadzone", T("Dead-zone colouring"),
        T("Colours the start and end of the swing, e.g. for proc weapons. Set the seconds below."), 10, y)
    add_color(panel, "ExtrasDeadzoneColor", "deadzone", T("Dead-zone colour"), SWATCH_X, swatch_y(y))
    -- the edit box titles sit 12px above each box
    panel.leading_editbox = addon_data.config.EditBoxFactory("ExtrasLeadingEditBox", panel,
        T("Leading (s)"), 70, 25, function(self)
            character_extras_settings.leading_deadzone = tonumber(self:GetText()) or 0
        end)
    panel.leading_editbox:SetPoint("TOPLEFT", 45, y - 46)
    panel.trailing_editbox = addon_data.config.EditBoxFactory("ExtrasTrailingEditBox", panel,
        T("Trailing (s)"), 70, 25, function(self)
            character_extras_settings.trailing_deadzone = tonumber(self:GetText()) or 0
        end)
    panel.trailing_editbox:SetPoint("TOPLEFT", 135, y - 46)

    -- Experimental
    y = y - 90
    local experimental = addon_data.config.TextFactory(panel, T("Experimental"), 16)
    experimental:SetPoint("TOPLEFT", 10, y)
    experimental:SetTextColor(1, 0.82, 0, 1)
    add_toggle(panel, "ExtrasCastResetCheckBox", "cast_reset", T("Reset swing after a spell cast"),
        T("Restarts your swing when a spell with a cast time finishes (not Slam). Check it matches your server."),
        10, y - 22)

    -- API
    local api = addon_data.config.TextFactory(panel,
        T("For macros/addons: /run print(WeaponSwingTimer_GetSwing(\"player\")) - also \"target\", \"off\""), 11)
    api:SetPoint("TOPLEFT", 10, y - 62)

    extras.config_frame = panel
    extras.UpdateConfigPanelValues()
end

extras.UpdateConfigPanelValues = function()
    local panel = extras.config_frame
    if not panel then return end
    local ex = S()
    for _, checkbox in ipairs(panel.toggles) do checkbox:SetChecked(ex[checkbox.wst_key]) end
    for _, picker in ipairs(panel.colors) do
        local k = picker.wst_key
        addon_data.compat.SetColorTexture(picker.foreground, ex[k .. "_r"], ex[k .. "_g"], ex[k .. "_b"], ex[k .. "_a"])
    end
    panel.leading_editbox:SetText(tostring(ex.leading_deadzone or 0))
    panel.leading_editbox:SetCursorPosition(0)
    panel.trailing_editbox:SetText(tostring(ex.trailing_deadzone or 0))
    panel.trailing_editbox:SetCursorPosition(0)
    panel.font_dropdown.Refresh()
    panel.texture_dropdown.Refresh()
    panel.border_dropdown.Refresh()
end
