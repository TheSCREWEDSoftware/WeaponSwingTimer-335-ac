-- Options window: one "WeaponSwingTimer" entry with a collapsible tree (AceConfig-3.0),
-- plus profile export/import codes.
local addon_name, addon_data = ...
local L = addon_data.localization_table

local options = {}
addon_data.options = options

local APP = "WeaponSwingTimer"
local function T(text) return (L and L[text]) or text end

local function P(section) return addon_data.db.profile[section] end

-- Don't redraw the window while a control is changing (sliders would jump)
local in_set = false
local function Refresh()
    in_set = true
    addon_data.core.UpdateAllVisualsOnSettingsChange()
    in_set = false
end
function options.NotifyChange()
    if in_set then return end
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then registry:NotifyChange(APP) end
end

-- Control builders (all read/write db.profile[section][key])
local function Toggle(section, key, name, desc, order, extra)
    local t = {
        type = "toggle", name = name, desc = desc, order = order,
        get = function() return P(section)[key] end,
        set = function(_, value) P(section)[key] = value and true or false; Refresh() end,
    }
    if extra then for k, v in pairs(extra) do t[k] = v end end
    return t
end

local function Range(section, key, name, desc, min, max, step, order, extra)
    local t = {
        type = "range", name = name, desc = desc, order = order,
        min = min, max = max, step = step,
        get = function() return P(section)[key] end,
        set = function(_, value) P(section)[key] = value; Refresh() end,
    }
    if extra then for k, v in pairs(extra) do t[k] = v end end
    return t
end

local function Color(section, key, name, desc, order, extra)
    local t = {
        type = "color", name = name, desc = desc, order = order, hasAlpha = true,
        get = function()
            local s = P(section)
            return s[key .. "_r"], s[key .. "_g"], s[key .. "_b"], s[key .. "_a"]
        end,
        set = function(_, r, g, b, a)
            local s = P(section)
            s[key .. "_r"], s[key .. "_g"], s[key .. "_b"], s[key .. "_a"] = r, g, b, a or 1
            Refresh()
        end,
    }
    if extra then for k, v in pairs(extra) do t[k] = v end end
    return t
end

local function Header(name, order) return { type = "header", name = name, order = order } end
local function Text(name, order) return { type = "description", name = name, order = order } end

local ALPHA = { isPercent = true }

-- Size, position and transparency for one bar
local function Layout(section, base, with_ooc)
    local args = {
        layout_header = Header(T("Size and position"), base),
        width = Range(section, "width", T("Bar Width"), nil, 50, 1000, 1, base + 1),
        height = Range(section, "height", T("Bar Height"), nil, 4, 100, 1, base + 2),
        fontsize = Range(section, "fontsize", T("Font Size"), nil, 6, 32, 1, base + 3),
        x_offset = Range(section, "x_offset", T("X Offset"), T("Horizontal position from the screen centre. You can also drag the bar while bars are unlocked."), -2000, 2000, 1, base + 4),
        y_offset = Range(section, "y_offset", T("Y Offset"), T("Vertical position from the screen centre. You can also drag the bar while bars are unlocked."), -2000, 2000, 1, base + 5),
        alpha_header = Header(T("Transparency"), base + 10),
        in_combat_alpha = Range(section, "in_combat_alpha", T("In Combat Alpha"), nil, 0, 1, 0.05, base + 11, ALPHA),
        backplane_alpha = Range(section, "backplane_alpha", T("Backplane Alpha"), nil, 0, 1, 0.05, base + 13, ALPHA),
    }
    if with_ooc then
        args.ooc_alpha = Range(section, "ooc_alpha", T("Out of Combat Alpha"), nil, 0, 1, 0.05, base + 12, ALPHA)
    end
    return args
end

local function Merge(a, b) for k, v in pairs(b) do a[k] = v end return a end

-- Melee bars (player and target share the same layout)
local function MeleeGroup(section, name, order, who)
    local args = {
        enabled = Toggle(section, "enabled", T("Enable"), T("Shows " .. who .. " swing bars."), 1),
        show_offhand = Toggle(section, "show_offhand", T("Show Off-Hand"), T("Shows the off-hand swing bar when dual wielding."), 2),
        show_border = Toggle(section, "show_border", T("Show border"), nil, 3),
        classic_bars = Toggle(section, "classic_bars", T("Classic bars"), T("Uses the classic bar texture and the spark at the end of the fill."), 4),
        fill_empty = Toggle(section, "fill_empty", T("Fill / Empty"), T("Determines if the bar is full or empty when a swing is ready."), 5),
        show_left_text = Toggle(section, "show_left_text", T("Show Left Text"), T("Shows the hand name."), 6),
        show_right_text = Toggle(section, "show_right_text", T("Show Right Text"), T("Shows the time left."), 7),
        color_header = Header(T("Colours"), 30),
        main = Color(section, "main", T("Main-hand Bar Color"), nil, 31),
        main_text = Color(section, "main_text", T("Main-hand Bar Text Color"), nil, 32),
        off = Color(section, "off", T("Off-hand Bar Color"), nil, 33),
        off_text = Color(section, "off_text", T("Off-hand Bar Text Color"), nil, 34),
    }
    return { type = "group", name = name, order = order, args = Merge(args, Layout(section, 10, true)) }
end

-- Ranged bars
-- Greyed out when the shot is instant on this client
local function ShotIsInstant(spell_id)
    local name = GetSpellInfo(spell_id)
    if not name or not addon_data.compat.IsSpellKnownByName(name) then return false end
    local _, _, _, cast_ms = addon_data.compat.GetSpellInfo(name)
    return cast_ms == 0
end
local function ShotToggle(key, name, spell_id, order)
    return Toggle("castbar", key, name, nil, order, {
        disabled = function() return ShotIsInstant(spell_id) end,
        desc = function()
            if ShotIsInstant(spell_id) then return T("Instant cast on this client, so there is no cast bar.") end
            return T("Shows the cast bar for this shot.")
        end,
    })
end

local function ShotGroup()
    local args = {
        info = Text(T("Shows the time until your next Auto Shot (Hunters) or wand Shoot (Mages, Priests, Warlocks). Only shown while a ranged weapon or wand is equipped."), 0),
        enabled = Toggle("hunter", "enabled", T("Enable"), nil, 1),
        show_border = Toggle("hunter", "show_border", T("Show border"), nil, 2),
        classic_bars = Toggle("hunter", "classic_bars", T("Classic bars"), nil, 3),
        one_bar = Toggle("hunter", "one_bar", T("YaHT / One bar"), T("Changes the Auto Shot bar to a single bar that fills from left to right"), 4),
        show_text = Toggle("hunter", "show_text", T("Show Text"), nil, 5),
        show_autoshot_delay_timer = Toggle("hunter", "show_autoshot_delay_timer", T("Auto Shot delay timer"), T("Shows a timer that represents when Auto shot is delayed."), 6),
        color_header = Header(T("Colours"), 30),
        cooldown = Color("hunter", "cooldown", T("Auto Shot Cooldown Color"), nil, 31),
    }
    return { type = "group", name = T("Shot bar"), order = 1, args = Merge(args, Layout("hunter", 10, true)) }
end

local function CastGroup()
    local args = {
        info = Text(T("Hunters only: a cast bar for shots with a cast time, such as Steady Shot."), 0),
        enabled = Toggle("castbar", "enabled", T("Enable"), nil, 1),
        show_border = Toggle("castbar", "show_border", T("Show border"), nil, 2),
        show_cast_text = Toggle("castbar", "show_cast_text", T("Show Cast Text"), nil, 3),
        show_latency_bars = Toggle("castbar", "show_latency_bars", T("Latency bar"), T("Shows a bar that represents latency on cast bar."), 4),
        shots_header = Header(T("Shots"), 5),
        show_multishot_cast_bar = ShotToggle("show_multishot_cast_bar", T("Multi-Shot cast bar"), 2643, 6),
        show_aimedshot_cast_bar = ShotToggle("show_aimedshot_cast_bar", T("Aimed Shot cast bar"), 19434, 7),
        show_steadyshot_cast_bar = ShotToggle("show_steadyshot_cast_bar", T("Steady Shot cast bar"), 34120, 8),
    }
    return { type = "group", name = T("Spell cast bar"), order = 2, args = Merge(args, Layout("castbar", 10, false)) }
end

-- Extras
local function MediaSelect(kind, name, order, desc)
    return {
        type = "select", name = name, desc = desc, order = order,
        values = function()
            local values = {}
            for _, entry in ipairs(addon_data.extras.MediaList(kind)) do values[entry.key] = entry.name end
            return values
        end,
        get = function() return P("extras")[kind] end,
        set = function(_, value) P("extras")[kind] = value; Refresh() end,
    }
end

local function ExtrasGroup()
    local half = { width = "half" }
    return {
        type = "group", name = T("Extras"), order = 30,
        args = {
            info = Text(T("Optional features. Everything here is off by default."), 0),
            appearance = {
                type = "group", name = T("Appearance"), order = 1,
                args = {
                    font = MediaSelect("font", T("Font"), 1),
                    timer_decimals = {
                        type = "select", name = T("Timer decimals"), order = 1.5,
                        desc = T("How the time left is written on the bars."),
                        values = { [1] = "1.3", [2] = "1.25" },
                        get = function() return P("extras").timer_decimals end,
                        set = function(_, value) P("extras").timer_decimals = value; Refresh() end,
                    },
                    bar_texture = MediaSelect("bar_texture", T("Bar texture"), 2),
                    border = MediaSelect("border", T("Border"), 3, T("Used when Show border is on.")),
                    vertical = Toggle("extras", "vertical", T("Vertical bars"), T("Player and target bars fill from bottom to top."), 4, { width = "full" }),
                },
            },
            colours = {
                type = "group", name = T("Swing bar colours"), order = 2,
                args = {
                    info = Text(T("Colours for your main-hand bar."), 0),
                    queued_color = Toggle("extras", "queued_color", T("Colour while a next-swing ability is queued"), T("Heroic Strike, Cleave, Maul, Raptor Strike or Rune Strike."), 1, { width = "double" }),
                    queued = Color("extras", "queued", T("Colour"), nil, 2),
                    haste_color = Toggle("extras", "haste_color", T("Colour when attack speed changes mid-swing"), T("For example a Flurry proc. Lasts until the next swing."), 3, { width = "double" }),
                    haste = Color("extras", "haste", T("Colour"), nil, 4),
                    slam_marker = Toggle("extras", "slam_marker", T("Slam marker (Warriors)"), T("Casting Slam after this marker delays your next swing."), 5, { width = "double" }),
                    slam = Color("extras", "slam", T("Colour"), nil, 6),
                    deadzone = Toggle("extras", "deadzone", T("Dead-zone colouring"), T("Colours the start and end of the swing, e.g. for proc weapons."), 7, { width = "double" }),
                    deadzone_c = Color("extras", "deadzone", T("Colour"), nil, 8),
                    leading_deadzone = Range("extras", "leading_deadzone", T("Leading (s)"), T("Seconds at the start of the swing."), 0, 3, 0.05, 9),
                    trailing_deadzone = Range("extras", "trailing_deadzone", T("Trailing (s)"), T("Seconds at the end of the swing."), 0, 3, 0.05, 10),
                },
            },
            highlight = {
                type = "group", name = T("New swing background"), order = 3,
                args = {
                    info = Text(T("Briefly changes a bar's background when its new swing starts."), 0),
                    hl_player_main = Toggle("extras", "hl_player_main", T("Your main hand"), nil, 1),
                    hl_player_main_c = Color("extras", "hl_player_main", T("Colour"), nil, 2),
                    br1 = Text("", 3),
                    hl_player_off = Toggle("extras", "hl_player_off", T("Your off hand"), nil, 4),
                    hl_player_off_c = Color("extras", "hl_player_off", T("Colour"), nil, 5),
                    br2 = Text("", 6),
                    hl_target_main = Toggle("extras", "hl_target_main", T("Target main hand"), nil, 7),
                    hl_target_main_c = Color("extras", "hl_target_main", T("Colour"), nil, 8),
                    br3 = Text("", 9),
                    hl_target_off = Toggle("extras", "hl_target_off", T("Target off hand"), nil, 10),
                    hl_target_off_c = Color("extras", "hl_target_off", T("Colour"), nil, 11),
                },
            },
            experimental = {
                type = "group", name = T("Experimental"), order = 4,
                args = {
                    cast_reset = Toggle("extras", "cast_reset", T("Reset swing after a spell cast"), T("Restarts your swing when a spell with a cast time finishes (not Slam). Check it matches your server."), 1, { width = "full" }),
                    api_header = Header(T("For macros and other addons"), 10),
                    api = Text('/run print(WeaponSwingTimer_GetSwing("player"))\n/run print(WeaponSwingTimer_GetSwing("player", "off"))\n/run print(WeaponSwingTimer_GetSwing("target"))\n\n' .. T("Returns the seconds until the next swing and the weapon speed."), 11),
                },
            },
        },
    }
end

-- Profile codes: "WST1:" + base64 of "WST1;section.key=t:value;..." (t = n/b/s).
-- Only settings that differ from the defaults are exported. Import resets to defaults first
-- and only accepts known settings of the right type.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Base64Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end
local B64_INDEX = {}
for i = 1, 64 do B64_INDEX[B64:sub(i, i)] = i - 1 end
local function Base64Decode(text)
    text = text:gsub("[^%w%+/=]", "")
    if #text % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #text, 4 do
        local s = text:sub(i, i + 3)
        local v1, v2 = B64_INDEX[s:sub(1, 1)], B64_INDEX[s:sub(2, 2)]
        local v3, v4 = B64_INDEX[s:sub(3, 3)], B64_INDEX[s:sub(4, 4)]
        if not v1 or not v2 then return nil end
        local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if s:sub(3, 3) ~= "=" then
            if not v3 then return nil end
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if s:sub(4, 4) ~= "=" then
            if not v4 then return nil end
            out[#out + 1] = string.char(n % 256)
        end
    end
    return table.concat(out)
end

local SECTIONS = { "core", "player", "target", "hunter", "castbar", "extras" }
local ANCHORS = { CENTER = 1, TOP = 1, BOTTOM = 1, LEFT = 1, RIGHT = 1, TOPLEFT = 1, TOPRIGHT = 1, BOTTOMLEFT = 1, BOTTOMRIGHT = 1 }
local function Defaults(section) return addon_data[section] and addon_data[section].default_settings end

local function Escape(s) return (s:gsub("[^%w _%-%.]", function(c) return string.format("%%%02X", c:byte()) end)) end
local function Unescape(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end

local function EncodeValue(v)
    local t = type(v)
    if t == "number" then return "n:" .. string.format("%.6g", v) end
    if t == "boolean" then return "b:" .. (v and "1" or "0") end
    if t == "string" then return "s:" .. Escape(v) end
end

function options.ExportProfile()
    local parts = { "WST1" }
    for _, section in ipairs(SECTIONS) do
        local defaults, current = Defaults(section), P(section)
        if defaults and current then
            local keys = {}
            for key in pairs(defaults) do keys[#keys + 1] = key end
            table.sort(keys)
            for _, key in ipairs(keys) do
                local value = current[key]
                local default = defaults[key]
                if type(value) == "table" then
                    local sub = {}
                    for k in pairs(value) do sub[#sub + 1] = k end
                    table.sort(sub)
                    for _, k in ipairs(sub) do
                        local e = EncodeValue(value[k])
                        if e and value[k] ~= (type(default) == "table" and default[k]) then
                            parts[#parts + 1] = section .. "." .. key .. "." .. k .. "=" .. e
                        end
                    end
                elseif value ~= default then
                    local e = EncodeValue(value)
                    if e then parts[#parts + 1] = section .. "." .. key .. "=" .. e end
                end
            end
        end
    end
    return "WST1:" .. Base64Encode(table.concat(parts, ";"))
end

-- Returns {section, key, subkey, value} entries, or nil and an error
function options.ParseCode(code)
    if type(code) ~= "string" then return nil, T("No code.") end
    code = code:gsub("%s", "")
    if code == "" then return nil, T("No code.") end
    if code:sub(1, 5) ~= "WST1:" then return nil, T("This is not a WeaponSwingTimer profile code.") end
    local data = Base64Decode(code:sub(6))
    if not data or (data ~= "WST1" and data:sub(1, 5) ~= "WST1;") then return nil, T("The code is damaged or incomplete.") end
    local valid_sections = {}
    for _, section in ipairs(SECTIONS) do valid_sections[section] = true end
    local entries, skipped = {}, 0
    for item in data:sub(6):gmatch("[^;]+") do
        local path, t, raw = item:match("^([%w_%.]+)=([nbs]):(.*)$")
        if not path then return nil, T("The code is damaged or incomplete.") end
        local section, key, sub = path:match("^(%w+)%.([%w_]+)%.?([%w_]*)$")
        local defaults = section and valid_sections[section] and Defaults(section)
        local default = defaults and defaults[key]
        local value
        if t == "n" then value = tonumber(raw)
        elseif t == "b" then value = (raw == "1")
        else value = Unescape(raw) end
        local ok = default ~= nil and value ~= nil
        if ok and sub ~= "" then
            ok = (key == "enabled_classes" and type(default) == "table" and default[sub] ~= nil and type(value) == "boolean")
        elseif ok then
            ok = (type(default) == type(value))
        end
        if ok and type(value) == "number" then
            ok = (value == value) and value > -100000 and value < 100000
        end
        if ok and (key == "point" or key == "rel_point") then ok = ANCHORS[value] ~= nil end
        if ok then
            entries[#entries + 1] = { section, key, (sub ~= "" and sub or nil), value }
        else
            skipped = skipped + 1
        end
    end
    if #entries == 0 and skipped > 0 then return nil, T("The code has no settings this version understands.") end
    return entries
end

local function ApplyEntries(entries)
    for _, e in ipairs(entries) do
        local section, key, sub, value = e[1], e[2], e[3], e[4]
        local target = P(section)
        if sub then
            if type(target[key]) ~= "table" then target[key] = {} end
            target[key][sub] = value
        else
            target[key] = value
        end
    end
    if addon_data.core.RefreshFromDB then addon_data.core.RefreshFromDB() end
    addon_data.core.UpdateAllVisualsOnSettingsChange()
end

function options.ImportCode(code, new_profile_name)
    local entries, err = options.ParseCode(code)
    if not entries then return false, err end
    if new_profile_name and new_profile_name ~= "" then
        addon_data.db:SetProfile(new_profile_name)
    end
    addon_data.db:ResetProfile()
    ApplyEntries(entries)
    return true, #entries
end

local share = { pending = "", new_name = "", status = "" }

local function ShareGroup()
    return {
        type = "group", name = T("Export / Import"), order = 200,
        args = {
            export_header = Header(T("Export"), 1),
            export_info = Text(T("Copy this code (click in the box, Ctrl+A, Ctrl+C) to share the current profile or move it to another account."), 2),
            export = {
                type = "input", name = T("Profile code"), order = 3, width = "full", multiline = 4,
                get = function() return options.ExportProfile() end,
                set = function() end,
            },
            import_header = Header(T("Import"), 10),
            import_info = Text(T("Paste a code, press Accept, then choose where to import it."), 11),
            import = {
                type = "input", name = T("Paste a code"), order = 12, width = "full", multiline = 4,
                get = function() return share.pending end,
                set = function(_, value)
                    share.pending = value or ""
                    local entries, err = options.ParseCode(share.pending)
                    share.status = entries and string.format(T("Valid code with %d settings."), #entries) or ("|cffff4040" .. err .. "|r")
                end,
            },
            status = { type = "description", order = 13, name = function() return share.status end },
            import_current = {
                type = "execute", name = T("Import into current profile"), order = 14, width = "double",
                desc = T("Replaces the matching settings of the profile you are using now."),
                confirm = true, confirmText = T("Overwrite the current profile with this code?"),
                disabled = function() return options.ParseCode(share.pending) == nil end,
                func = function()
                    local ok, result = options.ImportCode(share.pending)
                    share.status = ok and string.format(T("Imported %d settings into %s."), result, addon_data.db:GetCurrentProfile()) or ("|cffff4040" .. result .. "|r")
                end,
            },
            new_name = {
                type = "input", name = T("New profile name"), order = 15,
                get = function() return share.new_name end,
                set = function(_, value) share.new_name = (value or ""):gsub("^%s+", ""):gsub("%s+$", "") end,
            },
            import_new = {
                type = "execute", name = T("Import as a new profile"), order = 16,
                disabled = function() return options.ParseCode(share.pending) == nil or share.new_name == "" end,
                func = function()
                    local ok, result = options.ImportCode(share.pending, share.new_name)
                    share.status = ok and string.format(T("Imported %d settings into the new profile %s."), result, addon_data.db:GetCurrentProfile()) or ("|cffff4040" .. result .. "|r")
                end,
            },
        },
    }
end

-- Root
local function ClassValues()
    local values = {}
    for _, class in ipairs(addon_data.core.class_list) do
        local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            name = string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
        end
        values[class] = name
    end
    return values
end

function options.Build()
    local version = GetAddOnMetadata and GetAddOnMetadata(addon_name, "Version") or ""
    local root = {
        type = "group", name = APP, childGroups = "tree",
        args = {
            about = Text("|cff00ffb0" .. T("3.3.5a backport, made for AzerothCore") .. "|r   " .. (version or "") .. "\n"
                .. T("Based on WeaponSwingTimer-SixxFix by WatchYourSixx and the original by LeftHandedGlove.") .. "\n ", 1),
            general_header = Header(T("General"), 2),
            is_locked = {
                type = "toggle", name = T("Lock All Bars"), order = 3,
                desc = T("Locks all of the swing bar frames, preventing them from being dragged."),
                get = function() return P("player").is_locked end,
                set = function(_, value) addon_data.config.SetLocked(value) end,
            },
            preview = {
                type = "execute", order = 3.5,
                name = function() return addon_data.core.preview and T("Hide test bars") or T("Show test bars") end,
                desc = T("Shows the bars with sample values so you can drag them into place, even without a target, cast or ranged weapon. Stays on until you turn it off (also /wst test or right-click the minimap button)."),
                func = function() options.SetPreview(not addon_data.core.preview) end,
            },
            preview_possible_only = Toggle("core", "preview_possible_only", T("Test bars: only show bars this character can use"),
                T("Leaves out the shot bar for classes without Auto Shot or a wand, the spell cast bar for non-Hunters, and your off-hand row for classes that can't dual wield."), 3.6, { width = "full" }),
            only_class_bars = Toggle("core", "only_class_bars", T("Hide ranged bars this class can't use"),
                T("Shot bar: only Hunters, and Mages, Priests and Warlocks with a wand. Spell cast bar: only Hunters. Untick to allow them on any class."), 4.5, { width = "full" }),
            minimap = {
                type = "toggle", name = T("Show minimap button"), order = 4.7,
                desc = T("Left-click opens the options, right-click shows/hides all bars, drag to move."),
                get = function() return not addon_data.db.global.minimap.hide end,
                set = function(_, value)
                    addon_data.db.global.minimap.hide = not value
                    if options.minimap_button then options.minimap_button.Refresh() end
                end,
            },
            welcome_message = Toggle("core", "welcome_message", T("Welcome Message"), T("Displays the welcome message upon login/reload. Uncheck to disable."), 4),
            classes = {
                type = "multiselect", name = T("Show on classes"), order = 5,
                desc = T("The bars are only shown on characters of the ticked classes."),
                values = ClassValues,
                get = function(_, class)
                    local classes = P("core").enabled_classes
                    return not classes or classes[class] ~= false
                end,
                set = function(_, class, value)
                    local core = P("core")
                    core.enabled_classes = core.enabled_classes or {}
                    core.enabled_classes[class] = value and true or false
                    Refresh()
                end,
            },
            melee = {
                type = "group", name = T("Melee Settings"), order = 10,
                args = {
                    info = Text(T("Swing bars for you and your target."), 0),
                    player = MeleeGroup("player", T("Player bar"), 1, "your"),
                    target = MeleeGroup("target", T("Target bar"), 2, "your target's"),
                },
            },
            ranged = {
                type = "group", name = T("Ranged Settings"), order = 20,
                args = {
                    info = Text(T("Auto Shot / wand bar and the Hunter spell cast bar."), 0),
                    shot = ShotGroup(),
                    cast = CastGroup(),
                },
            },
            extras = ExtrasGroup(),
        },
    }
    local profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon_data.db)
    profiles.order = 100
    profiles.args.share = ShareGroup()
    root.args.profiles = profiles
    return root
end

-- The bar modules call these after a drag or profile change: redraw this window
for _, module in ipairs({ addon_data.player, addon_data.target, addon_data.hunter, addon_data.castbar }) do
    module.UpdateConfigPanelValues = options.NotifyChange
end
addon_data.config.UpdateConfigValues = options.NotifyChange
addon_data.extras.UpdateConfigPanelValues = options.NotifyChange

-- "Show all bars": every bar visible for positioning, until turned off
function options.SetPreview(on)
    addon_data.core.preview = on and true or false
    local label = addon_data.hunter.frame and addon_data.hunter.frame.wst_preview_label
    if label and not addon_data.core.preview then label:Hide() end
    addon_data.core.UpdateAllVisualsOnSettingsChange()
    if options.minimap_button then options.minimap_button.UpdateTooltip() end
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry then registry:NotifyChange(APP) end
    addon_data.utils.PrintMsg(addon_data.core.preview
        and T("Showing all bars. Drag them while bars are unlocked; /wst test or the minimap button (right-click) turns this off.")
        or T("Test bars off."))
end

-- Test bars: every row labelled with a sample fill from the left in its own colour
local SAMPLE = 0.6
local DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true, SHAMAN = true, DEATHKNIGHT = true }
local RANGED = { HUNTER = true, MAGE = true, PRIEST = true, WARLOCK = true }

local function Sample(bar, width, fraction)
    bar:ClearAllPoints()
    bar:SetWidth(math.max(width * fraction, 0.001))
    bar:Show()
end

local function PreviewMelee(module, s, who, show_off)
    local f = module.frame
    if character_extras_settings.vertical then return end  -- vertical bars keep their live layout
    local speed = (module.main_weapon_speed and module.main_weapon_speed > 0) and module.main_weapon_speed or 2.6
    Sample(f.main_bar, s.width, SAMPLE)
    f.main_bar:SetPoint("TOPLEFT", 0, 0)
    f.main_bar:SetVertexColor(s.main_r, s.main_g, s.main_b, s.main_a)
    f.main_spark:Hide()
    f.main_left_text:SetText(who .. " " .. T("Main-Hand"))
    f.main_right_text:SetText(addon_data.utils.FormatTime(speed * (1 - SAMPLE)))
    f.main_left_text:Show()
    f.main_right_text:Show()
    if show_off then
        Sample(f.off_bar, s.width, SAMPLE * 0.7)
        f.off_bar:SetPoint("BOTTOMLEFT", 0, 0)
        f.off_bar:SetVertexColor(s.off_r, s.off_g, s.off_b, s.off_a)
        f.off_spark:Hide()
        f.off_left_text:SetText(who .. " " .. T("Off-Hand"))
        f.off_right_text:SetText(addon_data.utils.FormatTime(speed * (1 - SAMPLE * 0.7)))
        f.off_left_text:Show()
        f.off_right_text:Show()
    else
        f.off_bar:Hide()
        f.off_left_text:Hide()
        f.off_right_text:Hide()
    end
    if not character_extras_settings.vertical then
        f:SetHeight(show_off and (s.height * 2 + 2) or s.height)
    end
end

function options.ShowPreview()
    local _, class = UnitClass("player")
    local possible_only = P("core").preview_possible_only
    local show = {
        player = true, target = true,
        hunter = not possible_only or RANGED[class],
        castbar = not possible_only or class == "HUNTER",
    }
    for key, module in pairs({ player = addon_data.player, target = addon_data.target, hunter = addon_data.hunter, castbar = addon_data.castbar }) do
        local frame = module.frame
        if frame then
            if show[key] then frame:Show(); frame:SetAlpha(1) else frame:Hide() end
        end
    end
    PreviewMelee(addon_data.player, character_player_settings, T("(Self)"), not possible_only or DUAL_WIELD[class])
    PreviewMelee(addon_data.target, character_target_settings, T("(Target)"), true)

    local h, hs = addon_data.hunter.frame, character_hunter_settings
    if not h.wst_preview_label then
        h.wst_preview_label = h:CreateFontString(nil, "OVERLAY")
        h.wst_preview_label:SetJustifyH("LEFT")
        h.wst_preview_label:SetShadowOffset(1, -1)
    end
    local label = h.wst_preview_label
    label:SetFont(addon_data.GetBarFont(), hs.fontsize)
    label:ClearAllPoints()
    label:SetPoint("LEFT", h, "LEFT", 2, 0)
    label:SetText(T("(Self) Ranged"))
    label:Show()
    Sample(h.shot_bar, hs.width, SAMPLE)
    h.shot_bar:SetPoint("BOTTOMLEFT", 0, 0)
    h.shot_bar:SetVertexColor(hs.cooldown_r, hs.cooldown_g, hs.cooldown_b, hs.cooldown_a)
    local range_speed = addon_data.hunter.range_speed or 3
    h.shot_bar_text:SetText(addon_data.utils.FormatTime(range_speed * (1 - SAMPLE)))

    local c, cs = addon_data.castbar.frame, character_castbar_settings
    Sample(c.spell_bar, cs.width, SAMPLE)
    c.spell_bar:SetPoint("TOPLEFT", 0, 0)
    c.spell_bar:SetVertexColor(0.7, 0.4, 0, 1)
    c.spell_spark:Hide()
    c.spell_text_center:SetText(T("(Self) Spell cast bar"))
    c.spell_text_center:Show()
    c.spell_bar_text:SetText(addon_data.utils.FormatTime(1.5 * (1 - SAMPLE), true))
    c.spell_bar_text:Show()
end

-- Minimap button: left-click options, right-click test bars, drag to move
function options.CreateMinimapButton()
    local settings = addon_data.db.global.minimap
    local b = CreateFrame("Button", "WeaponSwingTimerMinimapButton", Minimap)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetSize(31, 31)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\INV_Sword_04")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", 7, -5)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local function Place()
        local a = math.rad(settings.angle or 200)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
    end
    local function Drag()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        settings.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
        Place()
    end
    b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", Drag) end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            options.SetPreview(not addon_data.core.preview)
        else
            addon_data.compat.OpenOptions(addon_data.config.config_parent_panel)
        end
    end)
    function b.UpdateTooltip()
        if GameTooltip:GetOwner() ~= b then return end
        GameTooltip:ClearLines()
        GameTooltip:AddLine(APP)
        GameTooltip:AddLine(T("Left-click: options"), 1, 1, 1)
        GameTooltip:AddLine(addon_data.core.preview and T("Right-click: hide test bars") or T("Right-click: show all bars"), 1, 1, 1)
        GameTooltip:AddLine(T("Drag: move this button"), 1, 1, 1)
        GameTooltip:Show()
    end
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        b.UpdateTooltip()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function b.Refresh()
        if settings.hide then b:Hide() else Place(); b:Show() end
    end
    options.minimap_button = b
    b.Refresh()
end

-- Called once at load (from Config.InitializeVisuals)
function options.Register()
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(APP, options.Build)
    local panel = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(APP, APP)
    addon_data.config.config_parent_panel = panel
    options.CreateMinimapButton()
    for _, module in ipairs({ addon_data.player, addon_data.target, addon_data.hunter, addon_data.castbar }) do
        for _, key in ipairs({ "main_left_text", "main_right_text", "off_left_text", "off_right_text",
                               "shot_bar_text", "spell_bar_text", "spell_text_center" }) do
            local text = module.frame and module.frame[key]
            if text then
                text:SetShadowOffset(1, -1)
                text:SetShadowColor(0, 0, 0, 1)
            end
        end
    end
end
