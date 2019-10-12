-- Libvenus is a simple version manager for projects
local lib = {}
local filesystem = require("filesystem")

function lib.newKey()
	local key = string.format("%x", math.floor(math.random() * 999999999999)) -- max 12 len
	if key:len() < 12 then
		key = key .. string.rep("0", 12-key:len())
	end
	return key
end

function lib.readObject(dir, key)
	local paths = {
		object = dir .. "/objects/" .. key:sub(1, 2) .. "/" .. key,
		commit = dir .. "/commits/" .. key:sub(1, 2) .. "/" .. key,
		branch = dir .. "/branches/" .. key}
	local otype = nil
	local path = nil
	for k, v in pairs(paths) do
		if filesystem.exists(v) then
			otype = k
			path = v
		end
	end
	if path == nil then
		return nil, key .. " doesn't exists"
	end

	local stream, err = filesystem.open(path, "r")
	if not stream then
		return nil, err
	end

	if otype == "branch" then
		local kkey = stream:read(12)
		-- type is already known
		stream:read(7)
		local content = ""
		local data = ""
		while data ~= nil do
			content = content .. data
			data = stream:read(math.huge)
		end
		local childnum = string.byte(stream:read(1))
		local childs = {}
		for i=1, childnum do
			table.insert(childs, stream:read(12))
		end

		local obj = lib.branch(kkey, key)
		obj.childrens = childs
		return obj
	else
		local typeLen = string.byte(stream:read(1))
		local rtype = stream:read(typeLen)
		local content = ""
		local data = ""
		while data ~= nil do
			content = content .. data
			data = stream:read(math.huge)
		end

		local childs = {}
		if rtype == "tree" then
			local childnum = string.byte(stream:read(1))
			for i=1, childnum do
				table.insert(childs, stream:read(12))
			end
		end

		if rtype == "blob" then
			return lib.object(key, content)
		end

		if rtype == "tree" or rtype == "branch" then
			local parent = content:sub(1, 12)
			local name = content:sub(13, content:len())
			return ifOr(rtype == "tree", lib.tree(key, name, parent), lib.branch(key, name))
		end

		if rtype == "file" then
			local parent = content:sub(1, 12)
			local nameLen = string.byte(content:sub(13, 13))
			local name = content:sub(14, 14+nameLen)
			local text = content:sub(15+nameLen, content:len())
			return lib.file(key, name, parent, text)
		end

		if rtype == "commit" then
			local nameLen = string.byte(content:sub(1, 1))
			local name = content:sub(2, 2+nameLen)
			local objectNum = *

			
		end
	end
end

function lib.writeObjects(dir, objs)
	for _, v in pairs(objs) do
		lib.writeObject(dir, v)
	end
end

function lib.writeObject(dir, obj)
	if obj.type == "branch" then
		if not filesystem.exists(dir .. "/branches") then
			filesystem.makeDirectory(dir .. "/branches")
		end
		local stream, err = io.open(dir .. "/branches/" .. obj.name, "w")
		if not stream then
			error(err)
		end
		stream:write(obj.key)
		stream:write(string.char(obj.type:len()))
		stream:write(obj.type)
		stream:write(obj.content)
		stream:write(string.char(#obj.childrens))
		for _, v in pairs(obj.childrens) do
			stream:write(v)
		end
		stream:close()
	else
		local subdir = "/objects/"
		if obj.type == "commit" then
			subdir = "/commits/"
		end
		if not filesystem.exists(dir .. subdir .. obj.key:sub(1, 2)) then
			filesystem.makeDirectory(dir .. subdir .. obj.key:sub(1, 2))
		end
		print(dir .. subdir .. obj.key:sub(1, 2) .. "/" .. obj.key)
		local stream, err = io.open(dir .. subdir .. obj.key:sub(1, 2) .. "/" .. obj.key, "w")
		if not stream then
			error(err)
		end
		stream:write(string.char(obj.type:len()))
		stream:write(obj.type)
		stream:write(obj.content)
		if obj.type == "tree" then
			stream:write(string.char(#obj.childrens))
			for _, v in pairs(obj.childrens) do
				stream:write(v)
			end
		end
		stream:close()
	end
end

function lib.object(key, text)
	local obj = {
		key = key,
		content = text,
		type = "blob"
	}
	return obj
end

-- Files are objects capable of having a parent
function lib.file(key, name, parent, text)
	local str = parent .. string.char(name:len()) .. name .. text
	local obj = lib.object(key, str)
	obj.name = name
	obj.parent = parent
	obj.text = text
	obj.type = "file"
	return obj
end

-- Trees are objects capable of containing childrens and having a parent
-- Althought it can have a parent this isn't a file
function lib.tree(key, name, parent)
	local str = ""
	if parent then
		str = parent.key
	else
		str = "000000000000"
	end
	str = str .. name
	local obj = lib.object(key, str)
	obj.type = "tree"
	obj.childrens = {}
	obj.parent = parent
	obj.name = name
	if parent then
		table.insert(parent.childrens, obj.key)
	end
	return obj
end

-- Branches are trees stored as their name in the branches/ folder instdead of objects/
function lib.branch(key, name)
	local obj = lib.tree(key, name)
	obj.type = "branch"
	return obj
end

-- Commits are objects containing their name and what objects they pushed
function lib.commit(key, name, objects)
	local str = string.char(name:len()) .. name
	str = str .. string.char(#objects)
	for _, o in pairs(objects) do
		str = str .. o.key
	end
	local obj = lib.object(key, str)
	obj.type = "commit"
	obj.objects = objects
	return obj
end

return lib