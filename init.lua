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
	S = minetest.get_translator("meshport"),
}

modpath = minetest.get_modpath("meshport")
dofile(modpath .. "/utils.lua")
dofile(modpath .. "/mesh.lua")
dofile(modpath .. "/parse_obj.lua")
dofile(modpath .. "/nodebox.lua")
dofile(modpath .. "/export.lua")

local S = meshport.S
local vec = vector.new

minetest.register_privilege("meshport", S("Can save meshes with Meshport."))

minetest.register_on_leaveplayer(function(player, timed_out)
	local name = player:get_player_name()
	meshport.player_data[name] = nil
end)

for n = 1, 2 do
	local tex = "meshport_corner_" .. n .. ".png"

	minetest.register_entity("meshport:corner_" .. n, {
		initial_properties = {
			physical = false,
			visual = "cube",
			visual_size = {x = 1.04, y = 1.04, z = 1.04},
			selectionbox = {-0.52, -0.52, -0.52, 0.52, 0.52, 0.52},
			textures = {tex, tex, tex, tex, tex, tex},
			static_save = false,
			glow = minetest.LIGHT_MAX,
		},

		on_punch = function(self, hitter)
			self.object:remove()
		end,
	})
end

minetest.register_entity("meshport:border", {
	initial_properties = {
		physical = false,
		visual = "upright_sprite",
		textures = {
			"meshport_border.png",
			"meshport_border.png^[transformFX",
		},
		static_save = false,
		glow = minetest.LIGHT_MAX,
	},

	on_punch = function(self, hitter)
		if not hitter then
			return
		end

		local playerName = hitter:get_player_name()
		if not playerName then
			return
		end

		local borders = meshport.player_data[playerName].borders
		for i = 1, 6 do -- Remove all borders at once.
			if borders[i] then
				borders[i]:remove()
				borders[i] = nil
			end
		end
	end,
})

local SIDE_ROTATIONS = {
	vec(0.5 * math.pi, 0, 0), -- Y+
	vec(1.5 * math.pi, 0, 0), -- Y-
	vec(0, 1.5 * math.pi, 0), -- X+
	vec(0, 0.5 * math.pi, 0), -- X-
	vec(0, 0, 0), -- Z+
	vec(0, math.pi, 0), -- Z-
}


local function mark_borders(playerData)
	local pos1, pos2 = vector.sort(playerData.pos[1], playerData.pos[2])
	local center = vector.multiply(vector.add(pos1, pos2), 0.5)
	-- Add 0.01 to avoid z-fighting with blocks or corner markers.
	local c1, c2 = vector.subtract(pos1, 0.5 + 0.01), vector.add(pos2, 0.5 + 0.01)

	local sideCenters = {
		vec(center.x, c2.y, center.z), -- Y+
		vec(center.x, c1.y, center.z), -- Y-
		vec(c2.x, center.y, center.z), -- X+
		vec(c1.x, center.y, center.z), -- X-
		vec(center.x, center.y, c2.z), -- Z+
		vec(center.x, center.y, c1.z), -- Z-
	}

	local size = vector.subtract(c2, c1)
	local sideSizes = {
		{x = size.x, y = size.z}, -- Y+
		{x = size.x, y = size.z}, -- Y-
		{x = size.z, y = size.y}, -- X+
		{x = size.z, y = size.y}, -- X-
		{x = size.x, y = size.y}, -- Z+
		{x = size.x, y = size.y}, -- Z-
	}

	local half = vector.multiply(size, 0.5)
	local selectionBoxes = {
		{-half.x, -0.02, -half.z, half.x, 0, half.z}, -- Y+
		{-half.x, 0, -half.z, half.x, 0.02, half.z}, -- Y-
		{-0.02, -half.y, -half.z, 0, half.y, half.z}, -- X+
		{0, -half.y, -half.z, 0.02, half.y, half.z}, -- X-
		{-half.x, -half.y, -0.02, half.x, half.y, 0}, -- Z+
		{-half.x, -half.y, 0, half.x, half.y, 0.02}, -- Z-
	}

	for i = 1, 6 do
		local entity = minetest.add_entity(sideCenters[i], "meshport:border")
		entity:set_properties({
			visual_size = sideSizes[i],
			selectionbox = selectionBoxes[i],
		})
		entity:set_rotation(SIDE_ROTATIONS[i])
		playerData.borders[i] = entity
	end
end


local function set_position(playerName, n, pos)
	if not meshport.player_data[playerName] then
		meshport.player_data[playerName] = {
			pos = {},
			corners = {},
			borders = {},
		}
	end

	local data = meshport.player_data[playerName]
	data.pos[n] = pos

	if data.corners[n] then
		data.corners[n]:remove()
	end

	data.corners[n] = minetest.add_entity(pos, "meshport:corner_" .. n)

	for i = 1, 6 do
		if data.borders[i] then
			data.borders[i]:remove()
			data.borders[i] = nil
		end
	end

	if data.pos[1] and data.pos[2] then
		mark_borders(data)
	end

	meshport.log(playerName, "info", S("Position @1 set to @2.", n, minetest.pos_to_string(pos)))
end


for n = 1, 2 do
	minetest.register_chatcommand("mesh" .. n, {
		params = "[pos]",
		description = S(
			"Set position @1 for Meshport. Player's position is used if no other position is specified.", n),
		privs = {meshport = true},

		func = function(playerName, param)
			local pos

			if param == "" then
				pos = minetest.get_player_by_name(playerName):get_pos()
			else
				pos = minetest.string_to_pos(param)
			end

			if not pos then
				meshport.log(playerName, "error", S("Not a valid position."))
				return
			end

			pos = vector.round(pos)
			set_position(playerName, n, pos)
		end,
	})
end


local function on_wand_click(itemstack, player, pointedThing, n)
	if not player or pointedThing.type == "nothing" then
		return
	end

	local playerName = player:get_player_name()

	if not minetest.check_player_privs(playerName, "meshport") then
		meshport.log(playerName, "error", S("You must have the meshport privilege to use this tool."))
		return
	end

	local pos
	if pointedThing.type == "node" then
		if player:get_player_control().sneak then
			pos = pointedThing.above
		else
			pos = pointedThing.under
		end
	elseif pointedThing.type == "object" then
		local entity = pointedThing.ref:get_luaentity()
		if entity.name == "meshport:border" then
			return
		end

		pos = vector.round(pointedThing.ref:get_pos())
	else
		return -- In case another pointed_thing.type is added
	end

	set_position(playerName, n, pos)
end


minetest.register_tool("meshport:wand", {
	description = S("Meshport Area Selector\nLeft-click to set 1st corner, right-click to set 2nd corner."),
	short_description = S("Meshport Area Selector"),
	inventory_image = "meshport_wand.png",

	on_use = function(itemstack, placer, pointedThing) -- Left-click
		on_wand_click(itemstack, placer, pointedThing, 1)
	end,

	on_place = function(itemstack, placer, pointedThing) -- Right-click
		on_wand_click(itemstack, placer, pointedThing, 2)
		return itemstack -- Required by on_place
	end,

	on_secondary_use = function(itemstack, placer, pointedThing) -- Right-click on non-node
		on_wand_click(itemstack, placer, pointedThing, 2)
	end,
})

minetest.register_chatcommand("meshrst", {
	description = S("Clear the current Meshport area."),
	privs = {meshport = true},

	func = function(playerName, param)
		local data = meshport.player_data[playerName]
		if data then
			for n = 1, 2 do
				data.pos[n] = nil
				if data.corners[n] then
					data.corners[n]:remove()
					data.corners[n] = nil
				end
			end

			for i = 1, 6 do
				if data.borders[i] then
					data.borders[i]:remove()
					data.borders[i] = nil
				end
			end
		end

		meshport.log(playerName, "info", S("Cleared the current area."))
	end,
})

minetest.register_chatcommand("meshport", {
	params = "[filename]",
	description = S("Save a mesh of the selected area (filename optional)."),
	privs = {meshport = true},

	func = function(playerName, filename)
		local playerData = meshport.player_data[playerName] or {}

		if not (playerData.pos and playerData.pos[1] and playerData.pos[2]) then
			meshport.log(playerName, "error",
				S("No area selected. Use the Meshport Area Selector or /mesh1 and /mesh2 to select an area."))
			return
		end

		if filename:find("[^%w-_]") then
			meshport.log(playerName, "error",
				S("Invalid name supplied. Please use valid characters: [A-Z][a-z][0-9][-_]"))
			return
		elseif filename == "" then
			filename = os.date("%Y-%m-%d_%H-%M-%S")
		end

		local mpPath = minetest.get_worldpath() .. "/" .. "meshport"
		local folderName = playerName .. "_" .. filename

		if table.indexof(minetest.get_dir_list(mpPath, true), folderName) > 0 then
			meshport.log(playerName, "error",
				S("Folder \"@1\" already exists. Try using a different name.", folderName))
			return
		end

		local path = mpPath .. "/" .. folderName
		meshport.create_mesh(playerName, playerData.pos[1], playerData.pos[2], path)
	end,
})
