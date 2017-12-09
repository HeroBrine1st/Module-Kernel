local name = "Keyboard monitor"

local start = function() status("[" .. name .."] Initializing...") end
local onSignal = function(signal)
	if signal[1] == "key_down" then
		if signal[4] == 0x1D or signal[4] == 0x9D then _G.isCtrlPressed = true end
		if signal[4] == 0x36 or signal[4] == 0x2A then _G.isShiftPressed = true end
		if signal[4] == 0x38 or signal[4] == 0xB8 then _G.isAltPressed = true end
	elseif signal[1] == "key_up" then
		if signal[4] == 0x1D or signal[4] == 0x9D then _G.isCtrlPressed = false end
		if signal[4] == 0x36 or signal[4] == 0x2A then _G.isShiftPressed = false end
		if signal[4] == 0x38 or signal[4] == 0xB8 then _G.isAltPressed = false end
	end
end

return name, start, onSignal