local computer = computer
local benchmarkTime = 10

function benchmark(func)
	local time = 0
	local start = computer.uptime()
	while computer.uptime() < start+10 do
		local funcStart = computer.uptime()
		func()
		local funcTime = computer.uptime() - funcStart
		if time == 0 then
			time = funcTime
		else

		end
	end
	return time
end

print("Benchmarking..")
print("Minimum Event Pulling Time:")
local time = benchmark(function()
	computer.pullSignal(0.01)
	-- being 0.01 to avoid an optimization from OC that could ignore the function
end)
print("Average Time: " .. time)