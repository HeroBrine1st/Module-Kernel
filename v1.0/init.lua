local modules = {}
com = component
local charset = {}
for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end

function string.random(length)
  if length > 0 then
    return string.random(length - 1) .. charset[math.random(1, #charset)
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

if not screen or not gpu then error("Not enough gpu or screen",0) end

gpuAddress = nil
screenAddress = nil

local gpu = com.gpu
local fs = com.filesystem
local w, h = gpu.getResolution
local statusY = 1
local statusEnabled = true
function status(msg)
    local time = os.date('%X', lastmod)
    msg = "[" .. time .. "] " .. msg
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
		end
		buffer = buffer .. data
	until not data
	fs.close(handle)
	return load(buffer,"=" .. path)
end

