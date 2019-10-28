-- MineScape for Fushell
-- OHML v1.0.1 compliant viewer/browser
-- Partially compatible with OHML v1.0.2

package.loaded["xml"] = nil
local xml = require("xml")
local shell = require("shell")
local event = require("event")
local filesystem = require("filesystem")
local gpu = component.gpu
local width, height = gpu.getResolution()
local args, options = shell.parse(...)

if not args[1] then
	args[1] = "A:/Users/Shared/www/index.ohml"
end

local currentPath = args[1]

local stream = io.open(shell.resolve(args[1]))
local text = stream:read("a")
stream:close()

local parsed = xml.parse(text)

local cy = 3
local cx = 1
local objects = {}

local scriptProcesses = {}
local scriptId = 1
local scriptEnv

local function objectWrapper(obj)
	if obj.type == "canvas" then
		local wrapper = {
			drawText = function(x, y, text)
				if obj.drawHandler ~= nil then
					obj.drawHandler("text", x, y, text)
				end
			end,
			fillRect = function(x, y, width, height, char)
				if obj.drawHandler ~= nil then
					obj.drawHandler("fill", x, y, width, height, char)
				end
			end,
			setBackground = function(color, pal)
				if obj.drawHandler ~= nil then
					obj.drawHandler("setbg", color, pal)
				end
			end,
			setForeground = function(color)
				if obj.drawHandler ~= nil then
					obj.drawHandler("setfg", color)
				end
			end
		}
		return wrapper
	end
	return nil
end

local function makeScriptEnv()
	scriptEnv = {
		_G = scriptEnv,
		sleep = os.sleep,
		navigator = {
			appName = "Minescape",
			appCodeName = "Mozarella",
			product = "Geeko",
			appVersion = 0.9,
			userAgent = "Minescape/0.9 Geeko/1.0",
			platform = "Fuchas " .. _VERSION
		},
		document = {
			getElementById = function(id)
				for k, v in pairs(objects) do
					if v.tag and v.tag.attr.id == id then
						return objectWrapper(v)
					end
				end
			end
		},
		math = math,
		coroutine = coroutine,
		string = string,
		table = table,
		bit32 = bit32,
		tostring = tostring,
		tonumber = tonumber,
		ipairs = ipairs,
		load = load,
		next = next,
		pairs = pairs,
		pcall = pcall, xpcall = xpcall,
		select=  select,
		type = type,
		_VERSION = _VERSION
	}
end

local function cleanScripts()
	for k, v in pairs(scriptProcesses) do
		v:kill()
	end
end

makeScriptEnv()

local function loadScripts(tag)
	for _, v in pairs(tag.childrens) do
		if v.name == "#text" and v.parent.name == "script" and (not v.parent.attr.lang or v.parent.attr.lang == "application/lua") then
			local chunk, err = load(v.unformattedContent, "web-script", "t", scriptEnv)
			if not chunk then
				error(err)
			end
			local process = require("tasks").newProcess("luaweb-script-" .. scriptId, chunk)
			table.insert(scriptProcesses, process)
			scriptId = scriptId + 1
		else
			loadScripts(v)
		end
	end
end

local function resolve(tag)
	for _, v in pairs(tag.childrens) do
		if v.attr.x then
			cx = v.attr.x
		end
		if v.attr.y then
			cy = v.attr.y
		end
		if v.name == "#text" then
			if cx + v.content:len() > width then
				cx = 1
				cy = cy + 1
			end
			if v.parent.name == "a" then
				table.insert(objects, {
					type = "hyperlink",
					x = cx,
					y = cy,
					text = v.content,
					hyperlink = v.parent.attr.href,
					tag = v.parent
				})
			elseif v.parent.name == "script" then
				-- do nothing
			else
				table.insert(objects, {
					type = "text",
					x = cx,
					y = cy,
					text = v.content
				})
			end
			cx = cx + v.content:len()
		elseif v.name == "br" then
			cx = 1
			cy = cy + 1
			resolve(v)
		elseif v.name == "canvas" then
			table.insert(objects, {
				type = "canvas",
				x = cx,
				y = cy,
				width = v.attr.width or 16,
				height = v.attr.height or 8,
				drawHandler = nil,
				tag = v
			})
		else
			resolve(v)
			if v.name == "text" or v.name == "h1" or v.name == "h2" or v.name == "h3" or v.name == "h4" or v.name == "h5" then
				cx = 1
				cy = cy + 1
			end
		end
	end
end

local function render()
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
	local fore = 0xFFFFFF
	gpu.fill(1, 1, width, height, " ")
	gpu.set(width/2-4, 1, "MineScape")
	gpu.set(math.floor(width/2-(currentPath:len()/2)), 2, currentPath)
	gpu.set(1, height, "Ctrl+C: Exit")
	for _, obj in pairs(objects) do
		if obj.type == "text" then
			if fore ~= 0xFFFFFF then
				gpu.setForeground(0xFFFFFF)
				fore = 0xFFFFFF
			end
			gpu.set(obj.x, obj.y, obj.text)
		end
		if obj.type == "hyperlink" then
			if obj.trigerred then
				if fore ~= 0x2020AA then
					gpu.setForeground(0x2020AA)
					fore = 0x2020AA
				end
			else
				if fore ~= 0x2020FF then
					gpu.setForeground(0x2020FF)
					fore = 0x2020FF
				end
			end
			gpu.set(obj.x, obj.y, obj.text)
		end
		if obj.type == "canvas" then
			if obj.drawHandler == nil then
				local bg, fg = 0x000000, 0xFFFFFF
				obj.drawHandler = function(...)
					local pack = table.pack(...)
					local op, x, y, width, height = pack[1], pack[2] or 1, pack[3] or 1, pack[4] or 1, pack[5] or 1
					x = x+obj.x-1
					y = y+obj.y-1
					if x < obj.x then x = obj.x end
					if x > obj.x+obj.width then x = obj.x+obj.width end
					if y < obj.y then y = obj.y end
					if y > obj.y+obj.height then y = obj.y+obj.height end
					if type(width) == "number" then
						if width < 1 then width = 1 end
						--if x+width > obj.width then width = obj.width-x end
					end
					if type(width) == "number" then
						if height < 1 then heigth = 1 end
						--if y+height > obj.height then height = obj.height-y end
					end
					if op == "text" then
						gpu.setBackground(bg)
						gpu.setForeground(fg)
						gpu.set(x, y, pack[4])
					end
					if op == "fill" then
						gpu.setBackground(bg)
						gpu.fill(x, y, width, height, pack[6])
					end
					if op == "setbg" then
						bg = pack[2]
					end
					if op == "setfg" then
						fg = pack[2]
					end
				end
			end
		end
	end
end

local function go(link)
	if link:sub(1, 1) == "/" then
		currentPath = "A:" .. link
	else
		currentPath = filesystem.path(currentPath) .. link
	end
	stream = io.open(shell.resolve(currentPath))
	text = stream:read("a")
	stream:close()
	parsed = xml.parse(text)
	cx = 1
	cy = 3
	objects = {}
	cleanScripts()
	resolve(parsed)
	render()
	loadScripts(parsed)
end

cleanScripts()
resolve(parsed)
render()
loadScripts(parsed)

while true do
	local id, a, b, c = event.pull()
	if id == "interrupt" then
		break
	end
	if id == "touch" then
		local x = b
		local y = c
		for _, obj in pairs(objects) do
			if obj.type == "hyperlink" then
				if x >= obj.x and x < obj.x + obj.text:len() and y == obj.y then
					go(obj.hyperlink)
					break
				end
			end
		end
	end
end

gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, width, height, " ")
