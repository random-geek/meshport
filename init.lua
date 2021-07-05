--[[
	Copyright (C) 2021 random-geek (https://github.com/random-geek)

	This file is part of Meshport.

	Meshport is free software: you can redistribute it and/or modify it under
	the terms of the GNU Lesser General Public License as published by the Free
	Software Foundation, either version 3 of the License, or (at your option)
	any later version.

	Meshport is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
	FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for
	more details.

	You should have received a copy of the GNU Lesser General Public License
	along with Meshport. If not, see <https://www.gnu.org/licenses/>.
]]

meshport = {
	player_data = {},
}

modpath = minetest.get_modpath("meshport")
dofile(modpath .. "/utils.lua")
dofile(modpath .. "/mesh.lua")
dofile(modpath .. "/parse_obj.lua")
dofile(modpath .. "/nodebox.lua")
dofile(modpath .. "/export.lua")

minetest.register_privilege("meshport", "Can save meshes with meshport.")

minetest.register_on_leaveplayer(function(player, timed_out)
	local name = player:get_player_name()
	meshport.player_data[name] = nil
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
				meshport.log(name, "error", "Not a valid position.")
				return
			end

			pos = vector.round(pos)

			if not meshport.player_data[name] then
				meshport.player_data[name] = {}
			end

			if i == 1 then
				meshport.player_data[name].p1 = pos
			elseif i == 2 then
				meshport.player_data[name].p2 = pos
			end

			meshport.log(name, "info", string.format("Position %i set to %s.", i, minetest.pos_to_string(pos)))
		end,
	})
end

minetest.register_chatcommand("meshport", {
	params = "[filename]",
	description = "Save a mesh of the selected area (filename optional).",
	privs = {meshport = true},

	func = function(name, filename)
		local playerData = meshport.player_data[name] or {}

		if not playerData.p1 or not playerData.p2 then
			meshport.log(name, "error", "No area selected. Use /mesh1 and /mesh2 to select an area.")
			return
		end

		if filename:find("[^%w-_]") then
			meshport.log(name, "error", "Invalid name supplied. Please use valid characters ([A-Z][a-z][0-9][-_]).")
			return
		elseif filename == "" then
			filename = os.date("%Y-%m-%d_%H-%M-%S")
		end

		local mpPath = minetest.get_worldpath() .. DIR_DELIM .. "meshport"
		local folderName = name .. "_" .. filename

		if table.indexof(minetest.get_dir_list(mpPath, true), folderName) > 0 then
			meshport.log(name, "error",
				string.format("Folder %q already exists. Try using a different name.", folderName))
			return
		end

		local path = mpPath .. DIR_DELIM .. folderName
		meshport.create_mesh(name, playerData.p1, playerData.p2, path)
	end,
})
