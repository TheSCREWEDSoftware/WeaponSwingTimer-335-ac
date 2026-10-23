--[[
    WeaponSwingTimer-335-ac : 3.3.5a (Wrath of the Lich King, build 12340) compatibility layer.

    The original WeaponSwingTimer-SixxFix targets TBC Classic (2.5.x), which runs on the modern
    client API. This file bridges every API difference the addon relies on so the rest of the
    code -- and the look of the bars -- stays identical to the original.
]]
local addon_name, addon_data = ...

local compat = {}
addon_data.compat = compat

-- Media path follows the actual folder name so the addon works however the folder is named.
addon_data.media = "Interface\\AddOns\\" .. addon_name .. "\\Images\\"
addon_data.font = "Fonts\\FRIZQT__.TTF"

-- "BackdropTemplate" only exists on 9.x+ clients; on 3.3.5 every frame has SetBackdrop natively.
compat.BackdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

--[[------------------------------------------------------------------------------------------
    Widget polyfills (only applied when missing)
--------------------------------------------------------------------------------------------]]
do
    local probe = CreateFrame("Frame")
    local frame_mt = getmetatable(probe).__index
    local tex_mt = getmetatable(probe:CreateTexture()).__index
    local fs_mt = getmetatable(probe:CreateFontString()).__index
    for _, mt in ipairs({frame_mt, tex_mt, fs_mt}) do
        if type(mt) == "table" and not mt.SetSize then
            mt.SetSize = function(self, w, h) self:SetWidth(w) self:SetHeight(h) end
        end
    end
end

-- Texture:SetColorTexture does not exist on 3.3.5; SetTexture(r, g, b, a) is the equivalent.
compat.SetColorTexture = function(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

-- Backplane behind every bar: a solid dark fill plus the addon's cast-bar style border.
-- The fill is a plain color texture (always renders on 3.3.5, never comes out white);
-- the border is the original Border texture drawn as a backdrop edge.
compat.ApplyBackplane = function(backplane, show_border, alpha)
    if not backplane.wst_fill then
        backplane.wst_fill = backplane:CreateTexture(nil, "BACKGROUND")
        backplane.wst_fill:SetPoint("TOPLEFT", 8, -8)
        backplane.wst_fill:SetPoint("BOTTOMRIGHT", -8, 8)
    end
    compat.SetColorTexture(backplane.wst_fill, 0, 0, 0, alpha or 0.5)
    if show_border then
        local edge_file, edge_size = addon_data.media .. "Border", 12
        if addon_data.GetBorderInfo then edge_file, edge_size = addon_data.GetBorderInfo() end
        backplane:SetBackdrop({
            edgeFile = edge_file,
            tile = true, tileSize = 16, edgeSize = edge_size,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }})
        backplane:SetBackdropBorderColor(1, 1, 1, 1)
    else
        backplane:SetBackdrop(nil)
    end
end

-- GetNetStats: 3.3.5 returns (down, up, latency); modern clients add latencyHome/latencyWorld.
compat.GetLatency = function()
    local _, _, home, world = GetNetStats()
    return world or home or 0
end

--[[------------------------------------------------------------------------------------------
    Spell info
    3.3.5 GetSpellInfo: name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange
    Modern GetSpellInfo: name, rank, icon, castTime, minRange, maxRange, spellID
--------------------------------------------------------------------------------------------]]

-- Canonical IDs the hunter / castbar logic is written against. Any rank or name of these
-- spells is mapped back to the canonical ID, so WotLK ranks (e.g. Multi-Shot 49048) work.
local canonical_ids = {
    75,     -- Auto Shot
    5019,   -- Shoot (wand)
    5384,   -- Feign Death
    19506,  -- Trueshot Aura
    2643,   -- Multi-Shot
    19434,  -- Aimed Shot
    34120,  -- Steady Shot
}
local canonical_by_name = {}
local function BuildCanonical()
    for _, id in ipairs(canonical_ids) do
        local name = GetSpellInfo(id)
        if name then canonical_by_name[name] = id end
    end
end
BuildCanonical()

-- Returns the canonical spell ID for a spell ID or spell name; unknown spells pass through.
compat.NormalizeSpell = function(id_or_name)
    if id_or_name == nil then return nil end
    local name = id_or_name
    if type(id_or_name) == "number" then
        name = GetSpellInfo(id_or_name)
    end
    if name and canonical_by_name[name] then
        return canonical_by_name[name]
    end
    return id_or_name
end

-- GetSpellInfo returning the modern (classic-era) layout.
compat.GetSpellInfo = function(spell)
    local name, rank, icon, _, _, _, cast_time, min_range, max_range = GetSpellInfo(spell)
    if not name then return nil end
    local spell_id = type(spell) == "number" and spell or canonical_by_name[name]
    return name, rank, icon, cast_time, min_range, max_range, spell_id
end

--[[------------------------------------------------------------------------------------------
    Combat log
    3.3.5 CLEU payload: timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...
    Modern payload:     timestamp, event, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags,
                        dstGUID, dstName, dstFlags, dstRaidFlags, ...
    The addon parses the modern layout, so we rebuild it here.
--------------------------------------------------------------------------------------------]]
compat.BuildCombatInfo = function(...)
    if CombatLogGetCurrentEventInfo then
        return {CombatLogGetCurrentEventInfo()}
    end
    local timestamp, event, src_guid, src_name, src_flags, dst_guid, dst_name, dst_flags = ...
    local info = {
        timestamp, event, false, src_guid, src_name, src_flags, 0,
        dst_guid, dst_name, dst_flags, 0,
    }
    local n = select("#", ...)
    if event == "SWING_MISSED" then
        -- 3.3.5: missType, amountMissed      modern: missType, isOffHand, amountMissed
        info[12] = select(9, ...)
        info[13] = nil
        info[14] = select(10, ...)
        info.offhand_unknown = true
    else
        for i = 9, n do
            info[i + 3] = select(i, ...)
        end
        if event == "SWING_DAMAGE" then
            -- 3.3.5 has no isOffHand flag (suffix index 10). Mark it so the timers can infer it.
            info[21] = nil
            info.offhand_unknown = true
        end
    end
    -- Spell events carry spellId first: map ranks to the canonical IDs used by the addon.
    if type(info[12]) == "number" and event ~= "SWING_MISSED" and event ~= "SWING_DAMAGE"
       and event ~= "ENVIRONMENTAL_DAMAGE" then
        info[12] = compat.NormalizeSpell(info[12])
    end
    return info
end

-- 3.3.5 has no off-hand flag on swings. The hand that just swung is the one whose
-- timer is closest to (or past) ready, which is what every 3.3.5 swing timer relies on.
compat.SwingWasOffhand = function(unit_data)
    if not unit_data.has_offhand then
        return false
    end
    return unit_data.off_swing_timer < unit_data.main_swing_timer
end

--[[------------------------------------------------------------------------------------------
    UNIT_SPELLCAST_* events
    3.3.5: unit, spellName, spellRank[, lineID, spellID]     modern: unit, castGUID, spellID
--------------------------------------------------------------------------------------------]]
compat.SpellFromCastEvent = function(...)
    local unit, arg2, arg3, arg4, arg5 = ...
    local spell
    if type(arg5) == "number" then
        spell = arg5
    elseif type(arg3) == "number" then
        spell = arg3
    else
        spell = arg2
    end
    return unit, compat.NormalizeSpell(spell)
end

--[[------------------------------------------------------------------------------------------
    Interface options
--------------------------------------------------------------------------------------------]]
compat.RegisterOptionsPanel = function(panel)
    panel:Hide()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        if not panel.parent then
            local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
            Settings.RegisterAddOnCategory(category)
            compat.settings_category = category
            addon_data.config.settingsCategoryID = category:GetID()
        else
            Settings.RegisterCanvasLayoutSubcategory(compat.settings_category, panel, panel.name)
        end
    else
        InterfaceOptions_AddCategory(panel)
    end
end

compat.OpenOptions = function(panel)
    if Settings and Settings.OpenToCategory and addon_data.config.settingsCategoryID then
        Settings.OpenToCategory(addon_data.config.settingsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Called twice to work around the well known 3.3.5 bug where the first call
        -- only opens the frame without selecting the category.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

--[[------------------------------------------------------------------------------------------
    Color picker (3.3.5 uses the field based API instead of SetupColorPickerAndShow)
--------------------------------------------------------------------------------------------]]
compat.ShowColorPicker = function(info)
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
        return
    end
    ColorPickerFrame:Hide()
    ColorPickerFrame.func = info.swatchFunc
    ColorPickerFrame.opacityFunc = info.opacityFunc
    ColorPickerFrame.cancelFunc = info.cancelFunc
    ColorPickerFrame.hasOpacity = info.hasOpacity
    ColorPickerFrame.opacity = info.opacity
    ColorPickerFrame.previousValues = {info.r, info.g, info.b, info.opacity}
    ColorPickerFrame:SetColorRGB(info.r, info.g, info.b)
    ShowUIPanel(ColorPickerFrame)
end

compat.GetColorPickerAlpha = function()
    if ColorPickerFrame.GetColorAlpha then
        return ColorPickerFrame:GetColorAlpha()
    end
    return 1 - OpacitySliderFrame:GetValue()
end
