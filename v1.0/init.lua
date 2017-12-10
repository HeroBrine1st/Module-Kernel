local modules = {}
com = component
local charset = {}
for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

function string.random(length)
  if length > 0 then
    return string.random(length - 1) .. charset[math.random(1, #charset)]
  else
    return ""
  end
end

log = ""
_G.kernelversion = "Module Kernel v1.0"
for address, componentType in component.list() do
	if not com[componentType] then
		com[componentType] = component.proxy(address)
	end
end
com["filesystem"] = component.proxy(computer.getBootAddress())
local gpuAddress = component.list("gpu")()
local screenAddress = component.list("screen")()

if not screenAddress or not gpuAddress then error("Not enough gpu or screen",0) end

gpuAddress = nil
screenAddress = nil

local gpu = com.gpu
local fs = com.filesystem
local w, h = gpu.getResolution()
local statusY = 1
local statusEnabled = true
function status(msg)
	if not msg then return end
	msg = tostring(msg)
	if statusEnabled then
		gpu.setBackground(0x000000)
		gpu.setForeground(0xFFFFFF)
	    local time = os.date('%X', computer.uptime())
		msg = "[" .. tostring(time) .. "] " .. msg
		local x = 1
		local y = statusY
		gpu.set(x,y,msg)
		statusY = statusY + 1
		if statusY > h then
			statusY = h
			gpu.copy(1,1,w,h,0,-1)
		end
	end
	log = log .. msg .. "\n"
end
status("Booting kernel")


function readFile(path)
	local handle,res = fs.open(path,"r")
	if not handle then error(res) end
	local buffer = ""
	repeat
		local data, reason = fs.read(handle,math.huge)
		if not data and reason then
			error(reason)
		end
		if data then
			buffer = buffer .. data
		end
	until not data
	fs.close(handle)
	return buffer
end

function loadfile(path)
	return load(readFile(path),"=" .. path)
end

local function panic(reason)
	status("--------------------Error!--------------------")
	status("")
	status(reason)
	status("")
	status("----------------------------------------------")
	status("")
	status("Press any key for shutdown")
	computer.pullSignal()
	computer.shutdown()
end

status("Initializing kernel basic libraries")
kernel = {}
kernel.modules = {}
function kernel.loadModule(name)
	local path = "/module/" .. name .. ".lua"
	status("Loading module " .. path)
	if kernel.modules[name] then return kernel.modules[name] end
	local preLoad, reason = loadfile(path)
	if not preLoad then panic("Error in loading file " .. path .. ". Reason: " .. reason) end
	local returning = {pcall(preLoad)}
	if not returning[1] then panic(returning[2]) end
	kernel.modules[name] = returning[2]
	return table.unpack(returning,2,returning.n)
end
_G.isShiftPressed = false
_G.isCtrlPressed = false
_G.isAltPressed = false
local daemons = kernel.loadModule("daemons")
status("Writing new computer.pullSignal for daemons")
computer.pullSignal = daemons.pullSignal
local SCI,superuserkey = kernel.loadModule("SCI")

local daem = SCI.io.filesystem.list("/daemons/",superuserkey)
for i = 1, #daem do
	local name,start,onSignal = loadfile(SCI.io.filesystem.concat("/daemons/",daem[i]))()
	daemons.addDaemon(name,start,onSignal)
end
daemons.start()
status("Starting small lua interprepter")
local input, last
while true do
	input = nil
	input, last = SCI.io.screen.inputWord(1,48,160,3,"",0x000000,0xFFFFFF,1,1,last)
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
	status(tostring(input))
	if input then
		local func, reason = load(input,"=string","t",{SCI=SCI,status=status,SUkey = superuserkey})
		if not func then 
			status(reason)
		else
			local success, reason2 = pcall(func)
			if not success then status(reason2) end
		end
	end
end