local SCI = {
	io = {
		filesystem = {},
		screen = {},
	},
	network = {
		internet = {},
		modem = {},
	},
	device = {},
}
status("[SCI] Initializing...")
local com = com
fs = com.filesystem
local SUkey = string.random(128)
local serial = kernel.loadModule("serialization")
local permissions = {}
do
	status("[SCI] Reading permissions")
	local perFile = "/kernel/permissions"
	local handle, reason = fs.open(perFile,"r")
	if not handle then 
		status("[SCI] Error in opening file \"" .. perFile .. "\": " .. tostring(reason) .. ".")
		status("[SCI] Please create this file and will not remove it in future.")
		status("Press any key for shutdown.")
		computer.pullSignal()
		computer.shutdown()
	end
	local data = readFile(perFile)
	permissions = load("return " .. data)()
end

local function checkPermissions(path,superuserkey)
	local perm = {read=true,write=true}
	for key, value in pairs(permissions) do
		local len = key:len()
		if path:sub(1,len) == key then 
			if superuserkey == SUkey then perm = value.superuser else perm = value.user end
		end
	end
	return perm
end
local function requestOfDriverInstall(name)
	--здесь будет ваша функция запроса установки драйвера. Если устанавливать, возвращает true, иначе - false
	return false
end
-------------------------filesystem-------------------------
do

	local function segments(path)
	  path = path:gsub("\\", "/")
	  repeat local n; path, n = path:gsub("//", "/") until n == 0
	  local parts = {}
	  for part in path:gmatch("[^/]+") do
	    table.insert(parts, part)
	  end
	  local i = 1
	  while i <= #parts do
	    if parts[i] == "." then
	      table.remove(parts, i)
	    elseif parts[i] == ".." then
	      table.remove(parts, i)
	      i = i - 1
	      if i > 0 then
	        table.remove(parts, i)
	      else
	        i = 1
	      end
	    else
	      i = i + 1
	    end
	  end
	  return parts
	end

	function SCI.io.filesystem.getPermissions(path)
		for key, value in pairs(permissions) do
			local len = key:len()
			if path:sub(1,len) == key then 
				return value
			end
		end
	end
	function SCI.io.filesystem.setPermission(path,perms,superuserkey)
		checkArg(1,path,"string")
		checkArg(2,perms,"table")
		status("[SCI] Setting permissions for " .. path .. ".")
		if not superuserkey == SUkey then status("[SCI] Permission denied") return nil, "Permission denied" end
		permissions[path] = perms
		return true
	end	
	function SCI.io.filesystem.canonical(path)
	  local result = table.concat(segments(path), "/")
	  if unicode.sub(path, 1, 1) == "/" then
	    return "/" .. result
	  else
	    return result
	  end
	end

	function SCI.io.filesystem.concat(pathA, pathB, ...)
	  checkArg(1, pathA, "string")
	  local function concat(n, a, b, ...)
	    if not b then
	      return a
	    end
	    checkArg(n, b, "string")
	    return concat(n + 1, a .. "/" .. b, ...)
	  end
	  return SCI.io.filesystem.canonical(concat(2, pathA, pathB, ...))
	end

	function SCI.io.filesystem.path(path)
	  local parts = segments(path)
	  local result = table.concat(parts, "/", 1, #parts - 1) .. "/"
	  if unicode.sub(path, 1, 1) == "/" and unicode.sub(result, 1, 1) ~= "/" then
	    return "/" .. result
	  else
	    return result
	  end
	end

	function SCI.io.filesystem.name(path)
	  local parts = segments(path)
	  return parts[#parts]
	end

	function SCI.io.filesystem.getFileObject(path,superuserkey)
		if fs.isDirectory(path) then return nil, "Invalid path" end
		local object = {}
		local perm = checkPermissions(path,superuserkey)
		function object.read()
			status("[SCI] Reading file " .. path)
			if perm.read then
				return readFile(path)
			else
				status("[SCI] Permission denied")
				return nil, "Permission denied"
			end
		end
		function object.write(data)
			status("[SCI] Writing data to file " .. path)
			if perm.write then
				local handle, reason = fs.open(path,"w")
				if not handle then status("Error writing data: " .. reason or "underfined error") return nil, reason end
				fs.write(handle,data)
				fs.close(handle)
				return true
			else
				status("[SCI] Permission denied")
				return nil, "Permission denied"
			end
		end
		function object.create()
			status("[SCI] Creating file " .. path)
			if perm.write then
				local handle, reason = fs.open(path,"w")
				if not handle then status("Error creating file: " .. reason or "underfined error") return nil, reason end
				fs.write(handle,"")
				fs.close(handle)
				return true
			else
				status("[SCI] Permission denied")
				return nil, "Permission denied"
			end
		end
		function object.remove()
			status("[SCI] Removing file " .. path)
			if perm.write then
				return fs.remove(path)
			else
				status("[SCI] Permission denied")
				return nil, "Permission denied"
			end
		end
		function object.mkdirs()
			status("[SCI] Creating folders " .. path)
			if perm.write then
				return fs.makeDirectory(SCI.io.filesystem.path(path))
			else
				status("[SCI] Permission denied")
				return nil, "Permission denied"
			end
		end
		function object.exists()
			return fs.exists(path) 
		end
		function object.lastModified()
			return fs.lastModified(path)
		end
		function object.rewrite(data)
			object.remove()
			return object.write(data)
		end
		return object
	end
	function SCI.io.filesystem.list(path,superuserkey)
		status("[SCI] Receiving list of files in " .. path)
		local perm = checkPermissions(path,superuserkey)
		if not perm.read then status("[SCI] Permission denied") return {n=0}, "Permission denied" end
		return fs.list(path)
	end
end
---------------------------network--------------------------
do
	local buffer = {}
	
	function SCI.network.internet.request(url,post)
		if not com.internet then return nil, "Not available component \"internet\"" end
		local success, res = pcall(com.internet.request,url,post)
		if success then
			return function()
				while true do
					local data, reason = res.read()
					if not data then
						res.close()
						if reason then
							error(reason,2)
						else
							return nil
						end
					elseif #data > 0 then
						return data
					end
					os.sleep(0)
				end
			end
		else 
			return nil, res
		end
	end
	local buffer = kernel.loadModule("buffer")
	local socketStream = {}
	do
		function socketStream:close()
		  if self.socket then
		    self.socket.close()
		    self.socket = nil
		  end
		end

		function socketStream:seek()
		  return nil, "bad file descriptor"
		end

		function socketStream:read(n)
		  if not self.socket then
		    return nil, "connection is closed"
		  end
		  return self.socket.read(n)
		end

		function socketStream:write(value)
		  if not self.socket then
		    return nil, "connection is closed"
		  end
		  while #value > 0 do
		    local written, reason = self.socket.write(value)
		    if not written then
		      return nil, reason
		    end
		    value = string.sub(value, written + 1)
		  end
		  return true
		end
	end
	local function socket(address, port)
	  checkArg(1, address, "string")
	  checkArg(2, port, "number", "nil")
	  if port then
	    address = address .. ":" .. port
	  end

	  local inet = component.internet
	  local socket, reason = inet.connect(address)
	  if not socket then
	    return nil, reason
	  end

	  local stream = {inet = inet, socket = socket}
	  local metatable = {__index = socketStream,
	                     __metatable = "socketstream"}
	  return setmetatable(stream, metatable) end
	function SCI.network.internet.open(address, port)
		if not com.internet then return nil, "Not available component \"internet\"" end
		local stream, reason = socket(address, port)
		if not stream then
			return nil, reason
		end
		return buffer.new("rwb", stream)
	end
	if com.modem then SCI.network.modem = com.modem end
end
---------------------------screen--------------------------- 
do
	local gpu = com.gpu


	function SCI.io.screen.rememberOldPixels(x, y, x2, y2)
		local newPNGMassiv = { ["backgrounds"] = {} }
		local xSize, ySize = SCI.io.screen.getResolution()
		newPNGMassiv.x, newPNGMassiv.y = x, y
		--Перебираем весь массив стандартного PNG-вида по высоте
		local xCounter, yCounter = 1, 1
		for j = y, y2 do
		xCounter = 1
			for i = x, x2 do
				if (i > xSize or i < 0) or (j > ySize or j < 0) then
					error("Can't remember pixel, because it's located behind the screen: x("..i.."), y("..j..") out of xSize("..xSize.."), ySize("..ySize..")\n")
				end
				local symbol, fore, back = gpu.get(i, j)
				newPNGMassiv["backgrounds"][back] = newPNGMassiv["backgrounds"][back] or {}
				newPNGMassiv["backgrounds"][back][fore] = newPNGMassiv["backgrounds"][back][fore] or {}
				table.insert(newPNGMassiv["backgrounds"][back][fore], {xCounter, yCounter, symbol} )

				xCounter = xCounter + 1
				back, fore, symbol = nil, nil, nil
			end
			yCounter = yCounter + 1
		end
		return newPNGMassiv
	end
	 

	function SCI.io.screen.drawOldPixels(massivSudaPihay)
		--Перебираем массив с фонами
		for back, backValue in pairs(massivSudaPihay["backgrounds"]) do
			gpu.setBackground(back)
			for fore, foreValue in pairs(massivSudaPihay["backgrounds"][back]) do
				gpu.setForeground(fore)
				for pixel = 1, #massivSudaPihay["backgrounds"][back][fore] do
					if massivSudaPihay["backgrounds"][back][fore][pixel][3] ~= transparentSymbol then
						gpu.set(massivSudaPihay.x + massivSudaPihay["backgrounds"][back][fore][pixel][1] - 1, massivSudaPihay.y + massivSudaPihay["backgrounds"][back][fore][pixel][2] - 1, massivSudaPihay["backgrounds"][back][fore][pixel][3])
					end
				end
			end
		end
	end

	SCI.io.screen.getResolution = gpu.getResolution
	function SCI.io.screen.set(x,y,text,background,foreground)
		SCI.io.screen.setGroundColor(background,foreground)
		gpu.set(x,y,text)
	end
	function SCI.io.screen.fill(x,y,w,h,background,foreground,symbol)
		if not foreground or not symbol then foreground = 0x000000 symbol = " " end
		SCI.io.screen.setGroundColor(background,foreground)
		gpu.fill(x,y,w,h,symbol)
	end
	function SCI.io.screen.get(x,y) return gpu.get(x,y) end
	function SCI.io.screen.copy(x,y,w,h,delX,delY) return gpu.copy(x,y,w,h,delX,delY) end
	function SCI.io.screen.setGroundColor(back,fore) gpu.setBackground(back) gpu.setForeground(fore) end
	local function getLastSymbols(string,count)
		local len = string:len()
		local firstMarker = len-count+1
		if firstMarker < 1 then firstMarker = 1 end
		return string:sub(firstMarker,-1)
	end
	local function convertCode(code)
		local symbol
		if code ~= 0 and code ~= 13 and code ~= 8 and code ~= 9 and code ~= 200 and code ~= 208 and code ~= 203 and code ~= 205 and code ~= 0x9D and code ~= 0x1D and code ~= 0x1D and code ~= 0x36 and code ~= 0x38 and code ~= 0xB8 and code ~= 0x2A and code ~= 0x9D then
			symbol = unicode.char(code) 
			if _G.isShiftPressed then symbol = unicode.upper(symbol) end
		end
		return (symbol or "")
	end
	function SCI.io.screen.inputWord(x,y,w,h,text,textColor,inputColor,delX,delY)
		delX = delX or 0
		delY = delY or 0
		text = text or ""
		local screen = SCI.io.screen
		screen.fill(x,y,w,h,inputColor)
		while true do
			screen.set(x+delX,y+delY,getLastSymbols(text,w-delX*2),inputColor,textColor)
			local signal = {computer.pullSignal()}
			if signal[1] == "key_down" then
				if signal[4] == 28 then 
					return text, last
				elseif signal[4] == 14 then 
					text = text:sub(1,text:len()-1) 
					screen.fill(x,y,w,h,inputColor) 
				else
					text = text .. tostring(convertCode(signal[3]))
				end
			end
		end
	end
end
---------------------------drivers--------------------------
do

	status("[SCI] Initializing drivers")
	local driversPath = "/drivers/"
	function SCI.device.installDriver(path,name,SUkeyORrequest)
		status("[SCI] Installing driver " .. tostring(name) .. "...")
		local perm = {} 
		local superuserkey = ""
		if type(SUkeyORrequest) == "string" then
			perm = checkPermissions(SCI.io.filesystem.concat(driversPath,name),SUkeyORrequest)
			if not perm.write then status("[SCI] Permission denied") return nil, "Bad superuser key" end
			superuserkey = SUkeyORrequest 
		elseif type(SUkeyORrequest) == "boolean" and SUkeyORrequest == true then
			if requestOfDriverInstall(name) then superuserkey = SUkey end
		end
		if superuserkey == "" and not SUkeyORrequest then status("[SCI] Permission denied") return nil, "Bad superuserkey" end
		if superuserkey == "" then status("[SCI] User denied install") return nil, "User denied install" end
		local objectDriver = SCI.io.filesystem.getFileObject(SCI.io.filesystem.concat(driversPath,name),superuserkey)
		local objectFile = SCI.io.filesystem.getFileObject(path,superuserkey)
		objectDriver.mkdirs()
		objectDriver.rewrite(objectFile.read())
		status("[SCI] Installed")
		return true
	end
	for key, file in pairs(SCI.io.filesystem.list(driversPath,SUkey)) do
		if type(file) == "string" then
			status("[SCI] Loading driver " .. file .. "...")
			local success, reason = pcall(loadfile(SCI.io.filesystem.concat(driversPath,file)))
			if not success then status("[SCI] Error loading driver " .. name .. ":" .. reason) end
			if success then
				SCI.device[file] = reason
			end
		end
	end
end
---------------------------return---------------------------
status("[SCI] Initialized")
return SCI, SUkey