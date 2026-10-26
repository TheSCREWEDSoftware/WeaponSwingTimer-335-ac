-- 3.3.5a (12340) compatibility: bridges the API differences from TBC Classic so the rest of
-- the code stays close to the original.
local addon_name, addon_data = ...

local compat = {}
addon_data.compat = compat

-- Media path follows the folder name
addon_data.media = "Interface\\AddOns\\" .. addon_name .. "\\Images\\"

-- BackdropTemplate is 9.x+; on 3.3.5 every frame has SetBackdrop
compat.BackdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

-- Widget polyfills
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

-- No SetColorTexture on 3.3.5: SetTexture(r, g, b, a)
compat.SetColorTexture = function(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

-- Bar backplane: solid dark fill (never renders white) plus the chosen border
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

-- 3.3.5 GetNetStats: down, up, latency
compat.GetLatency = function()
    local _, _, home, world = GetNetStats()
    return world or home or 0
end

-- Spell info (3.3.5 GetSpellInfo has cost/funnel/power before castTime)

-- Any rank of these spells maps to the ID the hunter code uses
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

-- Spell ID or name -> canonical ID (unknown spells pass through)
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

-- Spellbook lookup by name (no IsSpellKnown on 3.3.5)
compat.IsSpellKnownByName = function(name)
    if not name or not GetSpellName then return false end
    local i = 1
    while true do
        local book_name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
        if not book_name then return false end
        if book_name == name then return true end
        i = i + 1
    end
end

-- GetSpellInfo in the modern return order
compat.GetSpellInfo = function(spell)
    local name, rank, icon, _, _, _, cast_time, min_range, max_range = GetSpellInfo(spell)
    if not name then return nil end
    local spell_id = type(spell) == "number" and spell or canonical_by_name[name]
    return name, rank, icon, cast_time, min_range, max_range, spell_id
end

-- Combat log: rebuild the modern argument layout from 3.3.5's
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
        -- 3.3.5 has no isOffHand here
        info[12] = select(9, ...)
        info[13] = nil
        info[14] = select(10, ...)
        info.offhand_unknown = true
    else
        for i = 9, n do
            info[i + 3] = select(i, ...)
        end
        if event == "SWING_DAMAGE" then
            -- no isOffHand on 3.3.5: the timers infer it
            info[21] = nil
            info.offhand_unknown = true
        end
    end
    -- map spell ranks to canonical IDs
    if type(info[12]) == "number" and event ~= "SWING_MISSED" and event ~= "SWING_DAMAGE"
       and event ~= "ENVIRONMENTAL_DAMAGE" then
        info[12] = compat.NormalizeSpell(info[12])
    end
    return info
end

-- The hand that swung is the one closest to ready
compat.SwingWasOffhand = function(unit_data)
    if not unit_data.has_offhand then
        return false
    end
    return unit_data.off_swing_timer < unit_data.main_swing_timer
end

-- UNIT_SPELLCAST_*: 3.3.5 passes unit, spellName, spellRank
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

-- Open the options (called twice: the first call on 3.3.5 doesn't select the category)
compat.OpenOptions = function(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end
