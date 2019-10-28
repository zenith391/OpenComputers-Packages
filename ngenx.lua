-- Ngenx OCranet server (formely Minehe)
package.loaded["network"] = nil

local event = require("event")
local network = require("network")
local security = require("security")
local tasks = require("tasks")
local args, options = require("shell").parse(...)

local function getNgenx()
	for _, v in pairs(tasks.getProcesses()) do
		if v.name == "ngenx" then
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
		local lines = ifOr(string.endsWith("\n"), string.split(request, "\n"), {request})

		local header = lines[1]
		local headerSplit = string.split(header)
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
	security.requestPermission("*") -- root
	local run = getNgenx()
	if run then
		print("Running")
	else
		-- The actual program thread
		local p = tasks.newProcess("ngenx", function()
			server()
		end)
		p:detach()
		print("Started")
	end
	return
end

if args[1] == "stop" then
	local run, p = getNgenx()
	if run then
		p:kill()
		print("Stopped")
	else
		print("Not running")
	end
	return
end

io.stderr:write("Usage: ngenx <start/stop>\n")