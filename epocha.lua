-- Epocha OCranet server (formely Ngenx which was formely Minehe)
package.loaded["network"] = nil

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
		local socket = network.listen(80, "modem")
		local request = socket:read()
		local lines = ifOr(string.endsWith(request, "\n"), string.split(request, "\n"), {request})

		local header = lines[1]
		local headerSplit = string.split(header, "\n")
		local properties = {}
		if headerSplit[1] ~= "OHTP/1.0" or headerSplit[2] ~= "GET" then
			socket:write("403")
			socket:close() -- invalid request
		end
		if #lines > 1 then
			for i=2,#lines do
				local line = lines[i]
				local lineSplit = string.split(line, ":")
				if #lineSplit > 1 then
					properties[lineSplit[1]] = lineSplit[2]
				end
			end
		end

		local stream = io.open(headerSplit[3], "r")
		if not stream then
			socket:write("404")
			socket:close()
		else
			local content = stream:read("*a")
			local response = "200"
			response = response .. "\nContent-Type: text/ohml"
			response = response .. "\n\n" .. content
			socket:write(response)
			socket:close()
		end
	end
end

if args[1] == "start" then
	local run = service()
	if run then
		print("Running")
	else
		-- The actual program thread
		security.requestPermission("*")
		tasks.getCurrentProcess().permissionGrant = function()
			return true
		end
		local p = tasks.newProcess("epocha-service", function()
			security.requestPermission("*")
			server()
		end)
		coroutine.yield()
		p:detach()
		print("'epocha-service' Started")
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

io.stderr:write("Usage: epocha <start/stop>\n")