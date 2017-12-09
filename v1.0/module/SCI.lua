local SCI = {
	io = {
		filesystem = {

		},
		screen = {

		}
	},
	network = {
		internet = {},
		modem = {}
	}
}

status("[SCI] Initializing...")
local com = com
fs = com.filesystem
local SUkey = string.random(128)
local serial = loadfile("/module/serialization.lua")()
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

----------------------filesystem----------------------------
do
	local function checkPermissions(path,superuserkey)
		local perm = {read=true,write=true,execute=true}
		for key, value in pairs(permissions) do
			local len = key:len()
			if path:sub(1,len) == key then 
				if superuserkey == SUkey then perm = value.superuser else perm = value.user end
			end
		end
		return perm
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
end

function SCI.io.filesystem.getFileObject(path,superuserkey)
	if not fs.exists(path) or fs.isDirectory(path) then return nil, "Invalid path" end
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
			if not handle then error(reason) end
			fs.write(handle,data)
			fs.close()
		else
			status("[SCI] Permission denied")
			return nil, "Permission denied"
		end
	end
	function object.create()
		status("[SCI] Creating file " .. path)
		if perm.write then
			local handle, reason = fs.open(path,"w")
			if not handle then error(reason) end
			fs.write(handle,"")
			fs.close()
		else
			status("[SCI] Permission denied")
			return nil, "Permission denied"
		end
	end
	function object.remove()
		status("[SCI] Removing file " .. path)
		if perm.write then
			fs.remove(path)
		else
			status("[SCI] Permission denied")
			return nil, "Permission denied"
		end
	end
	function object.mkdirs()
		status("[SCI] Creating folders " .. path)
		if perm.write then
			fs.makeDirectory(SCI.io.filesystem.path(path))
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
		object.write(data)
	end
	return object

	function SCI.io.filesystem.list(path,superuserkey)
		status("[SCI] Receiving list of files in " .. path)
		local perm = checkPermissions(path,superuserkey)
		if not perm.read then status("[SCI] Permission denied") return nil, "Permission denied" end
		return fs.list(path)
	end
end
-----------------------network------------------------------
do
	local buffer = {}
	
	function SCI.network.internet.request(url,post)
		if not com.isAvailable("internet") then return nil, "Not available component \"internet\"" end
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

		function internet.socket(address, port)
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
		  return setmetatable(stream, metatable)
		end end
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
		if not com.isAvailable("internet") then return nil, "Not available component \"internet\"" end
		local stream, reason = socket(address, port)
		if not stream then
			return nil, reason
		end
		return buffer.new("rwb", stream)
	end
end
return SCI, superuserkey
