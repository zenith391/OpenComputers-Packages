-- Geeko OHML Engine v1.0
-- OHML v1.0.1 compliant engine
-- Partially compatible with OHML v1.0.2 

local geeko = {
	-- The OS-independent filesystem API
	fs = nil,
	version = "0.2",
	browser = {"Unknown (name)", "Unknown (publisher or developer)", "1.0"},
	thread = nil,
	renderCallback = nil,
	log = nil,
	scriptEnv = {},
	runningScripts = {},
	objects = {},
	currentPath = "ohtp://geeko.com",
	os = "GeekOS/1.0"
}
local cx, cy = 1, 1
local scriptId = 1

-- Filesystem wrapper for OSes that exports a standard Lua "io" API.
local function fsLuaIO()
	return {
		readAll = function(path)
			local file = io.open(path, "r")
			local text = file:read("*a")
			file:close()
			return text
		end,
		parent = function(path)
			return require("filesystem").path(path)
		end
	}
end

local function ccIO() -- yup, Geeko supports ComputerCraft alongside OpenComputers
	return {
		readAll = fsLuaIO().readAll, -- same use of standard io library
		parent = function(path)
			return fs.getDir(path)
		end
	}
end

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

local function log(name, level, text)
	if geeko.log ~= nil and type(geeko.log) == "function" then
		geeko.log(name, level, tostring(text))
	end
end

local function makeScriptEnv()
	geeko.scriptEnv = {
		_G = geeko.scriptEnv,
		sleep = os.sleep,
		navigator = {
			appName = geeko.browser[1],
			appCreator = geeko.browser[2],
			engine = "Geeko",
			engineVersion = geeko.version,
			appVersion = geeko.browser[3],
			userAgent = geeko.browser[1] .. "/" .. geeko.browser[2] .. " Geeko/" .. geeko.version,
			platform = _OSVERSION or "unknown"
		},
		document = {
			getElementById = function(id)
				for k, v in pairs(geeko.objects) do
					if v.tag and v.tag.attr.id == id then
						return objectWrapper(v)
					end
				end
			end
		},
		console = {
			info = function(text)
				info("script", "info", text)
			end,
			warn = function(text)
				info("script", "warn", text)
			end,
			error = function(text)
				info("script", "error", text)
			end,
			log = function(text)
				info("script", "log", text)
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
		pcall = pcall,
		xpcall = xpcall,
		select = select,
		type = type,
		_VERSION = _VERSION
	}
end

-- This function must be called before exiting the browser, it
-- kills any child processes (mostly scripts) and do cleanup.
function geeko.clean()
	for k, v in pairs(geeko.runningScripts) do
		v:kill()
	end
end

local function loadScripts(tag)
	for _, v in pairs(tag.childrens) do
		if v.name == "#text" and v.parent.name == "script" and (not v.parent.attr.lang or v.parent.attr.lang == "application/lua") then
			local chunk, err = load(v.content, "web-script", "t", geeko.scriptEnv)
			if not chunk then
				error(err)
			end
			local process = require("tasks").newProcess("luaweb-script-" .. scriptId, chunk) -- TODO make it cross-compatible
			table.insert(geeko.runningScripts, process)
			scriptId = scriptId + 1
		else
			loadScripts(v)
		end
	end
end

function geeko.read(tag)
	for _, v in pairs(tag.childrens) do
		if v.attr.x then
			cx = v.attr.x
		end
		if v.attr.y then
			cy = v.attr.y
		end
		if v.name == "#text" then
			if cx + v.content:len() > 160 then
				cx = 1
				cy = cy + 1
			end
			if v.parent.name == "a" then
				table.insert(geeko.objects, {
					type = "hyperlink",
					x = cx,
					y = cy,
					width = v.content:len(),
					height = 1,
					text = v.content,
					hyperlink = v.parent.attr.href,
					tag = v.parent
				})
			elseif v.parent.name == "script" then
				-- handled by loadScripts
			else
				table.insert(geeko.objects, {
					type = "text",
					x = cx,
					y = cy,
					width = v.content:len(),
					height = 1,
					text = v.content
				})
			end
			cx = cx + v.content:len()
		elseif v.name == "br" then
			cx = 1
			cy = cy + 1
			geeko.read(v)
		elseif v.name == "canvas" then
			table.insert(geeko.objects, {
				type = "canvas",
				x = cx,
				y = cy,
				width = v.attr.width or 16,
				height = v.attr.height or 8,
				drawHandler = nil,
				tag = v
			})
		else
			geeko.read(v)
			if v.name == "text" or v.name == "h1" or v.name == "h2" or v.name == "h3" or v.name == "h4" or v.name == "h5" then
				cx = 1
				cy = cy + 1
			end
		end
	end
end

function geeko.url(link)
	local schemeEnd, pathStart = link:find("://", 1, true)
	local scheme, path = "", ""
	if not schemeEnd then
		return {
			scheme = nil,
			path = link
		}
	end
	return {
		scheme = link:sub(1, schemeEnd - 1),
		path = link:sub(pathStart + 1, link:len())
	}
end

function geeko.go(link)
	local schemeEnd = link:find("://", 1, true)
	local url, text = geeko.url(geeko.currentPath), ""

	if schemeEnd ~= nil then
		url = geeko.url(link)
		geeko.currentPath = link
	else
		if link:sub(1, 1) == "/" then
			geeko.currentPath = url.scheme .. "://" .. link
		else
			geeko.currentPath = url.scheme .. ":///" .. geeko.fs.parent(url.path) .. link
		end
		url = geeko.url(geeko.currentPath)
	end

	if url.scheme == "file" then
		text = geeko.fs.readAll(geeko.url(geeko.currentPath).path:sub(2))
	end

	parsed = require("xml").parse(text) -- wouldn't work on CC, to fix
	cx = 1
	cy = 1
	geeko.objects = {}
	geeko.clean()
	geeko.read(parsed)
	if geeko.renderCallback ~= nil and type(geeko.renderCallback) == "function" then
		geeko.renderCallback()
	else
		log("geeko", "warn", "render callback is not defined")
	end
	loadScripts(parsed)
end

-- OS init
if _OSDATA then -- Fuchas
	geeko.fs = fsLuaIO()
elseif _OSVERSION then -- OpenOS
	geeko.fs = fsLuaIO()
elseif rednet then
	geeko.fs = ccIO()
end

-- Geeko init
makeScriptEnv()

return geeko