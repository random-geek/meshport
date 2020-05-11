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
	params = "[filename]",
	description = "Save a mesh of the selected area (filename optional).",
	privs = {meshport = true},

	func = function(name, filename)
		if not meshport.p1[name] or not meshport.p2[name] then
			meshport.print(name, "error", "No area selected. Use /mesh1 and /mesh2 to select an area.")
			return
		end

		if filename:find("[^%w-_]") then
			meshport.print(name, "error", "Invalid name supplied. Please use valid characters ([A-Z][a-z][0-9][-_]).")
			return
		elseif filename == "" then
			filename = os.date("%Y-%m-%d_%H-%M-%S")
		end

		local mpPath = minetest.get_worldpath() .. DIR_DELIM .. "meshport"
		local folderName = name .. "_" .. filename

		if table.indexof(minetest.get_dir_list(mpPath, true), folderName) > 0 then
			meshport.print(name, "error",
				string.format("Folder %q already exists. Try using a different name.", folderName))
			return
		end

		local path = mpPath .. DIR_DELIM .. folderName
		meshport.create_mesh(name, meshport.p1[name], meshport.p2[name], path)
	end,
})
