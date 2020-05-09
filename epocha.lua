-- Epocha OCranet server (formely Ngenx which was formely Minehe)
package.loaded["network"] = nil

local EPOCHA_VERSION = "1.0"

local event = require("event")
local network = require("network")
local security = require("security")
local tasks = require("tasks")
local args, options = require("shell").parse(...)

local function service()
	for _, v in pairs(tasks.getProcesses()) do
		if v.name == "epocha-service" then
			return true, v
		end
	end
	return false
end

-- Server
local function server()
	while true do
		local socket = network.listen(80, "gert")
		local request = socket:read()
		local lines = (string.endsWith(request, "\n") and string.split(request, "\n")) or {request}

		local header = lines[1]
		local headerSplit = string.split(header, "\n")

		local requestHeaders = {}
		local responseHeaders = {
			["X-Powered-By"] = "Epocha " .. EPOCHA_VERSION
		}

		if headerSplit[1] ~= "OHTP/1.0" or headerSplit[2] ~= "GET" then
			socket:write("403")
			for k, v in pairs(responseHeaders) do
				response = "\n" .. response .. k .. ": " .. v
			end
			response = response .. "\n\n"
			socket:close() -- invalid request
		end
		if #lines > 1 then
			for i=2,#lines do
				local line = lines[i]
				local lineSplit = string.split(line, ":")
				if #lineSplit > 1 then
					requestHeaders[lineSplit[1]] = lineSplit[2]
				end
			end
		end

		local stream = io.open(headerSplit[3], "r")
		if not stream then
			socket:write("404")
			for k, v in pairs(responseHeaders) do
				response = "\n" .. response .. k .. ": " .. v
			end
			response = response .. "\n\n"
			socket:close()
		else
			local content = stream:read("a") -- "*a" is deprecated and only used in Lua 5.2 and not used at all in Fuchas's lib
			local response = "200"
			responseHeaders["Content-Type"] = "text/ohml"
			responseHeaders["Content-Size"] = string.rawlen(content)
			for k, v in pairs(responseHeaders) do
				response = "\n" .. response .. k .. ": " .. v
			end
			response = response .. "\n\n" .. content
			socket:write(response)
			socket:close()
		end
	end
end

if args[1] == "start" then
	local run = service()
	if run then
		print("The service is running.")
	else
		-- The actual program thread
		security.requestPermission("*")

		if options.s then -- synchronous
			print("Epocha " .. EPOCHA_VERSION)
			server()
		else
			tasks.getCurrentProcess().permissionGrant = function()
				return true
			end
			local p = tasks.newProcess("epocha-service", function()
				security.requestPermission("*")
				server()
			end)
			coroutine.yield()
			p:detach()
			print("Service started (pid " .. p.pid .. ").")
		end
	end
	return
end

if args[1] == "stop" then
	local run, p = service()
	if run then
		p:kill()
		print("Stopped")
	else
		print("Not running")
	end
	return
end

io.stderr:write("Usage: epocha <start/stop> [-s]\n")