-- MineScape for Fushell
-- Uses Geeko (formely Minescape's engine)

package.loaded["geeko"] = nil
local shell = require("shell")
local event = require("event")
local geeko = require("geeko")
local gpu = require("driver").gpu
local width, height = gpu.getResolution()
local args, options = shell.parse(...)

local xOffset, yOffset = 1, 2

if not args[1] then
	args[1] = "file:///A:/Users/Shared/www/index.ohml"
end

local currentPath = args[1]

geeko.browser = {"Minescape", "Zenith391 & Co.", "0.92"}
geeko.log = function(obj)
	gpu.drawText(1, 1, "Geeko] " .. tostring(obj))
end

local function render()
	gpu.setColor(0x000000)
	gpu.setForeground(0xFFFFFF)
	local fore = 0xFFFFFF
	gpu.fill(1, 1, width, height, " ")
	gpu.drawText(width/2-4, 1, "MineScape")
	gpu.drawText(math.floor(width/2-(currentPath:len()/2)), 2, currentPath)
	gpu.drawText(1, height, "Ctrl+C: Exit")
	gpu.drawText(14, height, "| Ctrl+T: Change URL")
	for _, obj in pairs(geeko.objects) do
		local ox, oy = obj.x + xOffset, obj.y + yOffset
		if oy > 3 - obj.height and ox < width and oy < height then
			if obj.type == "text" then
				if fore ~= 0xFFFFFF then
					gpu.setForeground(0xFFFFFF)
					fore = 0xFFFFFF
				end
				gpu.drawText(ox, oy, obj.text)
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
				gpu.drawText(ox, oy, obj.text)
			end
			if obj.type == "canvas" then
				if obj.drawHandler == nil then
					local bg, fg = 0x000000, 0xFFFFFF
					obj.drawHandler = function(...)
						local pack = table.pack(...)
						local op, x, y, width, height = pack[1], pack[2] or 1, pack[3] or 1, pack[4] or 1, pack[5] or 1
						x = x+ox-1
						y = y+oy-1
						if x < ox then x = ox end
						if x > ox+obj.width then x = ox+obj.width end
						if y < oy then y = oy end
						if y > oy+obj.height then y = oy+obj.height end
						if type(width) == "number" then
							if width < 1 then width = 1 end
							--if x+width > obj.width then width = obj.width-x end
						end
						if type(width) == "number" then
							if height < 1 then heigth = 1 end
							--if y+height > obj.height then height = obj.height-y end
						end
						if op == "text" then
							gpu.drawText(x, y, pack[4], fg, bg)
						end
						if op == "fill" then
							gpu.fill(x, y, width, height, pack[6], bg)
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
end

print("Opening " .. args[1])

geeko.renderCallback = render
geeko.go(args[1])

while true do
	local id, a, b, c = event.pull()
	if id == "interrupt" then
		break
	end
	if id == "touch" then
		local x = b
		local y = c
		for _, obj in pairs(geeko.objects) do
			if obj.type == "hyperlink" then
				if x >= obj.x and x < obj.x + obj.text:len() + xOffset and y == (obj.y+yOffset) then
					geeko.go(obj.hyperlink)
					break
				end
			end
		end
	end
	if id == "key_down" then
		local doRender = false
		if c == 200 then -- up
			yOffset = yOffset + 1
			doRender = true
		end
		if c == 203 then -- left
			xOffset = xOffset - 1
			doRender = true
		end
		if c == 205 then -- right
			xOffset = xOffset + 1
			doRender = true
		end
		if c == 208 then -- down
			yOffset = yOffset - 1
			doRender = true
		end
		if doRender then
			for _, obj in pairs(geeko.objects) do
				if obj.drawHandler then
					obj.drawHandler = nil
				end
			end
			geeko.renderCallback()
		end
	end
end

geeko.clean()
gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, width, height, " ")
