meshport = {
	p1 = {},
	p2 = {},
}

modpath = minetest.get_modpath("meshport")
dofile(modpath .. "/helpers.lua")
dofile(modpath .. "/api.lua")
dofile(modpath .. "/parse_obj.lua")
dofile(modpath .. "/nodebox.lua")
dofile(modpath .. "/export.lua")

minetest.register_privilege("meshport", "Can save meshes with meshport.")

minetest.register_on_leaveplayer(function(player, timed_out)
	local name = player:get_player_name()
	meshport.p1[name] = nil
	meshport.p2[name] = nil
end)

for i = 1, 2 do
	minetest.register_chatcommand("mesh" .. i, {
		params = "[pos]",
		description = string.format(
				"Set position %i for meshport. Player's position is used if no other position is specified.", i),
		privs = {meshport = true},

		func = function(name, param)
			local pos

			if param == "" then
				pos = minetest.get_player_by_name(name):get_pos()
			else
				pos = minetest.string_to_pos(param)
			end

			if not pos then
				meshport.print(name, "error", "Not a valid position.")
				return
			end

			pos = vector.round(pos)

			if i == 1 then
				meshport.p1[name] = pos
			elseif i == 2 then
				meshport.p2[name] = pos
			end

			meshport.print(name, "info", string.format("Position %i set to %s.", i, minetest.pos_to_string(pos)))
		end,
	})
end

minetest.register_chatcommand("meshport", {
	params = "",
	description = "Save a mesh of the selected area.",
	privs = {meshport = true},

	func = function(name, param)
		if not meshport.p1[name] or not meshport.p2[name] then
			meshport.print(name, "error", "No area selected. Use /mesh1 and /mesh2 to select an area.")
			return
		end

		meshport.create_mesh(name, meshport.p1[name], meshport.p2[name])
	end,
})
