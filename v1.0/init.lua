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

_G.log = ""
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
	log = log .. msg .. "\n"
end
status("Booting kernel")
function loadfile(path)
	local handle = fs.open(path,"r")
	local buffer = ""
	repeat
		local data, reason = fs.read(handle,math.huge)
		if not data and reason then
			error(reason)
		else
			error(reason)
		end
		buffer = buffer .. data
	until not data
	fs.close(handle)
	return load(buffer,"=" .. path)
end

function readFile(path)
	local handle = fs.open(path,"r")
	local buffer = ""
	repeat
		local data, reason = fs.read(handle,math.huge)
		if not data and reason then
			error(reason)
		else
			error(reason)
		end
		buffer = buffer .. data
	until not data
	fs.close(handle)
	return buffer
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
local kernel = {}
kernel.modules = {}
function kernel.loadModule(name)
	local path = "/module/" .. name .. ".lua"
	status("Loading module " .. path)
	if kernel.modules[name] then return kernel.modules[name] end
	local preLoad, reason = loadfile(path)
	if not preLoad then panic("Error in loading file " .. path .. ". Reason: " .. reason) end
	local returning = {preLoad()}
	kernel.modules[name] = returning[1]
	return table.unpack(returning)
end

local daemons = kernel.loadModule("daemons")
status("")
local SCI = kernel.loadModule("SCI")

panic("Test")
