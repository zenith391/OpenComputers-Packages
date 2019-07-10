local lib = {}
-- TODO

--- Format:
---   {
---     user = {
---       "name",
---       "age"
---     }
---   }
function lib.request(tab)
	local str = "{"
	for k, _ in pairs(tab) do
		str = str .. k
	end
	str = str .. "}"
end

return lib