-- Ngenx OCranet server (formely Minehe)
package.loaded["network"] = nil

local event = require("event")
local args, options = require("shell").parse(...)

local function getNgenx()
	for _, v in pairs(shin32.getProcesses()) do
		if v.name == "ngenx" then
			return true, v
		end
	end
	return false
end

if args[1] == "start" then
	local run = getNgenx()
	if run then
		print("Running")
	else
		-- The actual program thread
		local p = shin32.newProcess("ngenx", function()
			while true do
				local _ = event.pull("modem_message")
				print("Modem message!")
			end
		end)
		p:detach()
		print("Started")
	end
end

if args[1] == "stop" then
	local run, p = getNgenx()
	if run then
		p:kill()
		print("Stopped")
	else
		print("Not running")
	end
end