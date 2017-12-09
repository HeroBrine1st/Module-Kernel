local pullOrig = computer.pullSignal
local daemons = {daemons={}}
function daemons.pullSignal(...)
	local signal = {pullOrig(...)}
	if not signal[1] then return table.unpack(signal) end
	for i = 1, #daemons.daemons do
		local daemon = daemons.daemons[i]
		if daemon and daemon.onSignal then
			if notpcall then
				daemon.onSignal(signal)
			else
				local success, reason = pcall(daemon.onSignal,signal)
				if not success then status("Error executing daemon " .. daemon.name .. ". Reason: " .. reason) end
			end
		end
	end
	return table.unpack(signal)
end

function daemons.addDaemon(name,startFunc,onSignalFunc,notpcall)
	checkArg(1,name,"string")
	checkArg(2,startFunc,"function")
	checkArg(3,onSignalFunc,"function")
	table.insert(daemons.daemons,{name=name,start=startFunc,onSignal=onSignalFunc,notpcall=notpcall})
	status("Added daemon " .. name)
end

local function pullFilteredSignal(timeout,filter)
	local time = computer.uptime() + timeout
	while time - computer.uptime() > 0 do
		local signal = {pullOrig(time - computer.uptime())}
		if signal[1] == filter then return table.unpack(signal) end
	end
	return nil
end

function daemons.start()
	status("Starting daemons")
	for i = 1, #daemons.daemons do
		status("Starting " .. daemons.daemons[i].name .. "...")
		local success, reason = pcall(daemons.daemons[i].start)
		if not success then 
			status("Daemon starting error. Reason: " .. reason or "underfined error.")
			status("10 seconds for rebooting system. For resume booting, please press any key.")
			if not pullOrig(10) then computer.shutdown(true) end
		end
	end
end

return daemons