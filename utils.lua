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

local S = meshport.S

meshport.NEIGHBOR_DIRS = {
	-- face neighbors
	vector.new( 0, 1, 0), -- 1
	vector.new( 0,-1, 0),
	vector.new( 1, 0, 0),
	vector.new(-1, 0, 0),
	vector.new( 0, 0, 1),
	vector.new( 0, 0,-1),

	-- edge neighbors
	vector.new(-1, 1, 0), -- 7
	vector.new( 1, 1, 0),
	vector.new( 0, 1, 1),
	vector.new( 0, 1,-1),
	vector.new(-1, 0, 1),
	vector.new( 1, 0, 1),
	vector.new(-1, 0,-1),
	vector.new( 1, 0,-1),
	vector.new(-1,-1, 0),
	vector.new( 1,-1, 0),
	vector.new( 0,-1, 1),
	vector.new( 0,-1,-1),
}

local FACEDIR_TO_TILE_INDICES = {
	[0] =
	{1, 2, 3, 4, 5, 6},
	{1, 2, 5, 6, 4, 3},
	{1, 2, 4, 3, 6, 5},
	{1, 2, 6, 5, 3, 4},
	{6, 5, 3, 4, 1, 2},
	{3, 4, 5, 6, 1, 2},
	{5, 6, 4, 3, 1, 2},
	{4, 3, 6, 5, 1, 2},
	{5, 6, 3, 4, 2, 1},
	{4, 3, 5, 6, 2, 1},
	{6, 5, 4, 3, 2, 1},
	{3, 4, 6, 5, 2, 1},
	{4, 3, 1, 2, 5, 6},
	{6, 5, 1, 2, 4, 3},
	{3, 4, 1, 2, 6, 5},
	{5, 6, 1, 2, 3, 4},
	{3, 4, 2, 1, 5, 6},
	{5, 6, 2, 1, 4, 3},
	{4, 3, 2, 1, 6, 5},
	{6, 5, 2, 1, 3, 4},
	{2, 1, 4, 3, 5, 6},
	{2, 1, 6, 5, 4, 3},
	{2, 1, 3, 4, 6, 5},
	{2, 1, 5, 6, 3, 4},
}

local FACEDIR_TO_TILE_ROTATIONS = {
	[0] =
	{0, 0, 0, 0, 0, 0},
	{1, 3, 0, 0, 0, 0},
	{2, 2, 0, 0, 0, 0},
	{3, 1, 0, 0, 0, 0},
	{0, 2, 1, 3, 2, 0},
	{0, 2, 1, 3, 3, 3},
	{0, 2, 1, 3, 0, 2},
	{0, 2, 1, 3, 1, 1},
	{2, 0, 3, 1, 2, 0},
	{2, 0, 3, 1, 1, 1},
	{2, 0, 3, 1, 0, 2},
	{2, 0, 3, 1, 3, 3},
	{1, 1, 1, 1, 3, 1},
	{1, 1, 2, 0, 3, 1},
	{1, 1, 3, 3, 3, 1},
	{1, 1, 0, 2, 3, 1},
	{3, 3, 3, 3, 1, 3},
	{3, 3, 2, 0, 1, 3},
	{3, 3, 1, 1, 1, 3},
	{3, 3, 0, 2, 1, 3},
	{2, 2, 2, 2, 2, 2},
	{1, 3, 2, 2, 2, 2},
	{0, 0, 2, 2, 2, 2},
	{3, 1, 2, 2, 2, 2},
}

local WALLMOUNTED_TO_FACEDIR = {[0] = 20, 0, 17, 15, 8, 6}

local DRAWTYPE_ALIASES = {
	allfaces_optional = "allfaces",
	glasslike_framed_optional = "glasslike",
}


function meshport.log(name, level, s)
	local message

	if level == "info" then
		message = minetest.colorize("#00EF00", s)
	elseif level == "warning" then
		message = minetest.colorize("#EFEF00", S("Warning: @1", s))
	elseif level == "error" then
		message = minetest.colorize("#EF0000", S("Error: @1", s))
	end

	minetest.chat_send_player(name, "[meshport] " .. message)
end


function meshport.rotate_vector_by_facedir(vec, facedir)
	local v = vector.new(vec)
	local rotY = facedir % 4
	local rotSide = (facedir - rotY) / 4

	-- Rotate the vector. Values of 0 for either `rotY` or `rotSide` do not change the vector.
	if rotY == 1 then
		v.x, v.z = v.z, -v.x -- 90 degrees clockwise
	elseif rotY == 2 then
		v.x, v.z = -v.x, -v.z -- 180 degrees clockwise
	elseif rotY == 3 then
		v.x, v.z = -v.z, v.x -- 270 degrees clockwise
	end

	if rotSide == 1 then
		v.y, v.z = -v.z, v.y -- Facing Z+
	elseif rotSide == 2 then
		v.y, v.z = v.z, -v.y -- Facing Z-
	elseif rotSide == 3 then
		v.x, v.y = v.y, -v.x -- Facing X+
	elseif rotSide == 4 then
		v.x, v.y = -v.y, v.x -- Facing X-
	elseif rotSide == 5 then
		v.x, v.y = -v.x, -v.y -- Facing Y-
	end

	return v
end


function meshport.translate_texture_coordinates(texCoords, offset)
	if offset.x == 0 and offset.y == 0 then
		return texCoords
	end

	local newTexCoords = {}

	for _, tc in ipairs(texCoords) do
		table.insert(newTexCoords, {x = tc.x + offset.x, y = tc.y + offset.y})
	end

	return newTexCoords
end


function meshport.rotate_texture_coordinates_rad(texCoords, rad)
	if rad == 0 then
		return texCoords
	end

	local sinRad = math.sin(rad)
	local cosRad = math.cos(rad)
	local newTexCoords = {}

	for _, texCoord in ipairs(texCoords) do
		-- Coordinates are rotated around (0.5, 0.5).
		local x = texCoord.x - 0.5
		local y = texCoord.y - 0.5
		table.insert(newTexCoords, {
			x = x * cosRad - y * sinRad + 0.5,
			y = x * sinRad + y * cosRad + 0.5
		})
	end

	return newTexCoords
end


local function rotate_texture_coordinates(texCoords, rot)
	if rot == 0 then
		return
	end

	for i, tc in ipairs(texCoords) do
		local x, y

		-- Rotate the vector. Values of components range from 0 to 1, so adding 1 when inverting is necessary.
		if rot == 1 then
			x, y = 1 - tc.y, tc.x -- 90 degrees counterclockwise
		elseif rot == 2 then
			x, y = 1 - tc.x, 1 - tc.y -- 180 degrees counterclockwise
		elseif rot == 3 then
			x, y = tc.y, 1 - tc.x -- 270 degrees counterclockwise
		end

		texCoords[i] = {x = x, y = y}
	end
end


local function scale_global_texture_coordinates(texCoords, pos, sideIdx, scale)
	-- Get the offset of the tile relative to the lower left corner of the texture.
	local texPos = {}

	if sideIdx == 1 then
		texPos.x = pos.x % 16 % scale
		texPos.y = pos.z % 16 % scale
	elseif sideIdx == 2 then
		texPos.x = pos.x % 16 % scale
		texPos.y = scale - pos.z % 16 % scale - 1
	elseif sideIdx == 3 then
		texPos.x = pos.z % 16 % scale
		texPos.y = pos.y % 16 % scale
	elseif sideIdx == 4 then
		texPos.x = scale - pos.z % 16 % scale - 1
		texPos.y = pos.y % 16 % scale
	elseif sideIdx == 5 then
		texPos.x = scale - pos.x % 16 % scale - 1
		texPos.y = pos.y % 16 % scale
	elseif sideIdx == 6 then
		texPos.x = pos.x % 16 % scale
		texPos.y = pos.y % 16 % scale
	end

	-- Scale and move the texture coordinates.
	for i, texCoord in ipairs(texCoords) do
		texCoords[i] = {
			x = (texCoord.x + texPos.x) / scale,
			y = (texCoord.y + texPos.y) / scale,
		}
	end
end


-- WARNING: This function mutates tables!
-- Please follow the table rules used by Faces.
function meshport.prepare_cuboid_face(face, tiles, pos, facedir, sideIdx)
	-- If the tile index has not been set manually, assign a tile to the face based on the facedir value.
	face.tile_idx = face.tile_idx or FACEDIR_TO_TILE_INDICES[facedir][sideIdx]
	local tile = meshport.get_tile(tiles, face.tile_idx)

	if tile.align_style == "world" or tile.align_style == "user" then
		-- For scaled, world-aligned tiles, scale and reposition the texture coordinates as needed.
		if tile.scale and tile.scale ~= 1 then
			scale_global_texture_coordinates(face.tex_coords, pos, sideIdx, tile.scale)
		end
	else
		-- If the tile isn't world-aligned, rotate it according to the facedir.
		rotate_texture_coordinates(face.tex_coords, FACEDIR_TO_TILE_ROTATIONS[facedir][sideIdx])
	end

	return face
end


function meshport.get_content_id_or_nil(nodeName)
	if minetest.registered_nodes[nodeName] then
		return minetest.get_content_id(nodeName)
	end
end


function meshport.get_def_from_id(contentId)
	return minetest.registered_nodes[minetest.get_name_from_content_id(contentId)] or {}
end


function meshport.get_aliased_drawtype(drawtype)
	return DRAWTYPE_ALIASES[drawtype or ""] or drawtype
end


function meshport.get_facedir(type, param2)
	if type == "facedir" or type == "colorfacedir" then
		-- For colorfacedir, only the first 5 bits are needed.
		return param2 % 32
	elseif type == "wallmounted" or type == "colorwallmounted" then
		-- For colorwallmounted, only the first 3 bits are needed. If the wallmounted direction is invalid, return 0.
		return WALLMOUNTED_TO_FACEDIR[param2 % 8] or 0
	else
		return 0
	end
end


function meshport.get_degrotate(type, param2)
	if type == "degrotate" then
		return 1.5 * (param2 % 240)
	elseif type == "colordegrotate" then
		return 15 * ((param2 % 32) % 24)
	else
		return 0
	end
end


function meshport.get_node_neighbors(array, area, idx)
	-- Get the node's absolute position from the flat array index.
	local pos = area:position(idx)
	local neighbors = {}

	-- Get the content/param2 value for each neighboring node.
	for i = 1, 6 do
		neighbors[i] = array[area:indexp(vector.add(pos, meshport.NEIGHBOR_DIRS[i]))]
	end

	return neighbors
end


function meshport.get_tile(tiles, n)
	if type(tiles) == "table" and #tiles > 0 then
		return tiles[n] or tiles[#tiles]
	else
		return "unknown"
	end
end


local function get_png_dimensions(path)
	-- Luckily, reading the dimensions of a PNG file is a trivial task
	local file = io.open(path, "rb")
	if not file then
		return
	end
	file:seek("set", 1)
	if file:read(3) ~= "PNG" then -- Verify it's a PNG file
		return
	end
	file:seek("set", 16)

	local function read_u32(b)
		return (b:byte(1) * 0x1000000 +
				b:byte(2) * 0x10000 +
				b:byte(3) * 0x100 +
				b:byte(4))
	end

	local w = read_u32(file:read(4))
	local h = read_u32(file:read(4))
	file:close()

	return w, h
end


-- In case of failure, this should return nil, nil
function meshport.get_texture_dimensions(textureName)
	local dims = meshport.texture_dimension_cache[textureName]
	if dims then
		return dims[1], dims[2]
	end

	local path = meshport.texture_paths[textureName]
	if path then
		local w, h = get_png_dimensions(path)
		meshport.texture_dimension_cache[path] = {w, h} -- Will be an empty table if the file isn't found.
		return w, h
	end
end


function meshport.get_asset_paths(assetFolderName, extension)
	local modAssetPath
	local assets = {}

	-- Iterate through each enabled mod.
	for _, modName in ipairs(minetest.get_modnames()) do
		modAssetPath = minetest.get_modpath(modName) .. "/" .. assetFolderName

		-- Iterate through all the files in the requested folder of the mod.
		for _, fileName in ipairs(minetest.get_dir_list(modAssetPath, false)) do
			-- Add files to the table. If an extension is specified, only add files with that extension.
			if not extension or string.lower(string.sub(fileName, -string.len(extension))) == extension then
				assets[fileName] = modAssetPath .. "/" .. fileName
			end
		end
	end

	return assets
end
