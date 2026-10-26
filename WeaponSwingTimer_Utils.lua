local addon_name, addon_data = ...

addon_data.utils = {}

-- Sends the given message to the chat frame with the addon name in front.
addon_data.utils.PrintMsg = function(msg)
	local chat_msg = "|cFF00FFB0" .. addon_name .. ": |r" .. msg
	DEFAULT_CHAT_FRAME:AddMessage(chat_msg)
end

-- Rounds the given number to the given step.
-- If num was 1.17 and step was 0.1 then this would return 1.1
addon_data.utils.SimpleRound = function(num, step)
    return floor(num / step) * step
end

-- Timer text: "1.3" (original) or "1.25" (Extras > Appearance > Timer decimals)
addon_data.utils.FormatTime = function(t, fixed)
    local ex = character_extras_settings
    if ex and ex.timer_decimals == 2 then
        return string.format("%.2f", math.max(floor(t * 100) / 100, 0))
    end
    if fixed then return string.format("%.1f", math.max(addon_data.utils.SimpleRound(t, 0.1), 0)) end
    return tostring(addon_data.utils.SimpleRound(t, 0.1))
end

