local filesystem = require("filesystem")
local args = {...}
local file = io.open(args[1], "rb")

local dent = {
	magic = 0,
	dev = 0,
	ino = 0,
	mode = 0,
	uid = 0,
	gid = 0,
	nlink = 0,
	rdev = 0,
	mtime = 0,
	namesize = 0,
	filesize = 0,
}

local function readint(amt, rev)
	local tmp = 0
	for i=(rev and amt) or 1, (rev and 1) or amt, (rev and -1) or 1 do
		tmp = bit32.bor(tmp, (bit32.lshift(file:read(1):byte(), ((i-1)*8))))
	end
	return tmp
end

local function fwrite()
	local dir = dent.name:match("(.+)/.*%.?.+")
	if (dir) then
		filesystem.makeDirectory("A:/" .. os.getenv("PWD") .. "/" .. dir)
	end
	local hand = io.open(dent.name, "w")
	hand:write(file:read(dent.filesize))
	hand:close()
end

while true do
	dent.magic = readint(2)
	local rev = false
	if (dent.magic ~= tonumber("070707", 8)) then rev = true end
	dent.dev = readint(2)
	dent.ino = readint(2)
	dent.mode = readint(2)
	dent.uid = readint(2)
	dent.gid = readint(2)
	dent.nlink = readint(2)
	dent.rdev = readint(2)
	dent.mtime = bit32.bor(bit32.lshift(readint(2), 16) | readint(2))
	dent.namesize = readint(2)
	dent.filesize = bit32.bor(bit32.lshift(readint(2), 16) | readint(2))
	local name = file:read(dent.namesize):sub(1, dent.namesize-1)
	if (name == "TRAILER!!!") then break end
	dent.name = name
	print("Extracting " .. name)
	if (dent.namesize % 2 ~= 0) then
		file:seek("cur", 1)
	end
	if (dent.mode & 32768 ~= 0) then
		fwrite()
	end
	if (dent.filesize % 2 ~= 0) then
		file:seek("cur", 1)
	end
end