local filesystem = require("filesystem")
local file = io.open("A:/mandelbrot.b", "r")
local txt = file:read("a")
--local bf = string.toCharArray(txt)

local brackets = {}
local mem = {0}
local ptr = 1

local waitDepth = 0
local waitBracket = false

local i = 1
while i < #txt do
	local c = txt:sub(i, i)
	--io.stdout:write(c)
	if waitBracket then
		if c == '[' then
			waitDepth = waitDepth + 1
		end
		if c == ']' then
			waitDepth = waitDepth - 1
			if waitDepth == -1 then
				waitBracket = false
			end
		end
	else
		if c == '>' then
			ptr = ptr + 1
			if not mem[ptr] then
				mem[ptr] = 0 -- init cell
			end
		end
		if c == '<' then
			ptr = ptr - 1
			if not mem[ptr] then
				mem[ptr] = 0 -- init cell
			end
		end
		if c == '+' then
			mem[ptr] = mem[ptr] + 1
		end
		if c == '-' then
			mem[ptr] = mem[ptr] - 1
		end
		if c == '.' then
			if mem[ptr] == string.byte('\n') or mem[ptr] == string.byte('\r') then
				io.stdout:write(' \n')
			else
				io.stdout:write(string.char(mem[ptr]))
			end
			coroutine.yield()
		end
		if c == '[' then
			if mem[ptr] == 0 then
				waitBracket = true
				waitDepth = 0
			else
				table.insert(brackets, i)
			end
		end
		if c == ']' then
			local p = table.remove(brackets)
			if mem[ptr] ~= 0 then
				i = p-1
			end
		end
	end
	--coroutine.yield()
	i = i + 1
end
io.stdout:write(" \n")

file:close()