meshport.neighbor_dirs = {
	{x = 0, y = 1, z = 0}, -- Y+
	{x = 0, y = -1, z = 0}, -- Y-
	{x = 1, y = 0, z = 0}, -- X+
	{x = -1, y = 0, z = 0}, -- X-
	{x = 0, y = 0, z = 1}, -- Z+
	{x = 0, y = 0, z = -1}, -- Z-
}

meshport.facedir_to_tile_indices = {
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

meshport.facedir_to_tile_rotations = {
	[0] =
	{0, 0, 0, 0, 0, 0},
	{3, 1, 0, 0, 0, 0},
	{2, 2, 0, 0, 0, 0},
	{1, 3, 0, 0, 0, 0},
	{0, 2, 3, 1, 2, 0},
	{0, 2, 3, 1, 1, 1},
	{0, 2, 3, 1, 0, 2},
	{0, 2, 3, 1, 3, 3},
	{2, 0, 1, 3, 2, 0},
	{2, 0, 1, 3, 3, 3},
	{2, 0, 1, 3, 0, 2},
	{2, 0, 1, 3, 1, 1},
	{3, 3, 3, 3, 1, 3},
	{3, 3, 2, 0, 1, 3},
	{3, 3, 1, 1, 1, 3},
	{3, 3, 0, 2, 1, 3},
	{1, 1, 1, 1, 3, 1},
	{1, 1, 2, 0, 3, 1},
	{1, 1, 3, 3, 3, 1},
	{1, 1, 0, 2, 3, 1},
	{2, 2, 2, 2, 2, 2},
	{3, 1, 2, 2, 2, 2},
	{0, 0, 2, 2, 2, 2},
	{1, 3, 2, 2, 2, 2},
}

meshport.wallmounted_to_facedir = {[0] = 20, 0, 17, 15, 8, 6}

meshport.drawtype_aliases = {
	allfaces_optional = "allfaces",
	glasslike_framed_optional = "glasslike_framed",
}

function meshport.print(name, level, s)
	local message

	if level == "info" then
		message = minetest.colorize("#00EF00", s)
	elseif level == "warning" then
		message = minetest.colorize("#EFEF00", "Warning: " .. s)
	elseif level == "error" then
		message = minetest.colorize("#EF0000", "Error: " .. s)
	end

	minetest.chat_send_player(name, "[meshport] " .. message)
end

function meshport.find_or_insert(list, value)
	local idx = table.indexof(list, value)

	-- If the element does not exist, create it.
	if idx < 0 then
		table.insert(list, value)
		idx = #list
	end

	-- Return the index of the element.
	return idx
end

function meshport.clean_vector(vec)
	-- Prevents an issue involving negative zero values, which are not handled properly by `string.format`.
	return {
		x = vec.x == 0 and 0 or vec.x,
		y = vec.y == 0 and 0 or vec.y,
		z = vec.z == 0 and 0 or vec.z,
	}
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

function meshport.rotate_texture_coordinate(texCoord, rot)
	local vt = table.copy(texCoord)

	-- Rotate the vector. Values of components range from 0 to 1, so adding 1 when inverting is necessary.
	if rot == 1 then
		vt.x, vt.y = vt.y, 1 - vt.x -- 90 degrees clockwise
	elseif rot == 2 then
		vt.x, vt.y = 1 - vt.x, 1 - vt.y -- 180 degrees clockwise
	elseif rot == 3 then
		vt.x, vt.y = 1 - vt.y, vt.x -- 270 degrees clockwise
	end

	return vt
end

function meshport.rotate_texture_coordinates(texCoords, rot)
	if rot == 0 then
		return texCoords
	end

	local newTexCoords = {}

	for _, texCoord in ipairs(texCoords) do
		table.insert(newTexCoords, meshport.rotate_texture_coordinate(texCoord, rot))
	end

	return newTexCoords
end

function meshport.scale_global_texture_coordinates(texCoords, pos, sideIdx, scale)
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
	local newTexCoords = {}

	for _, texCoord in ipairs(texCoords) do
		table.insert(newTexCoords, {
			x = (texCoord.x + texPos.x) / scale,
			y = (texCoord.y + texPos.y) / scale,
		})
	end

	return newTexCoords
end

function meshport.prepare_cuboid_face(face, tiles, pos, facedir, sideIdx)
	-- If the tile index has not been set manually, assign a tile to the face based on the facedir value.
	face.tile_idx = face.tile_idx or meshport.facedir_to_tile_indices[facedir][sideIdx]
	local tile = meshport.get_tile(tiles, face.tile_idx)

	if tile.align_style == "world" or tile.align_style == "user" then
		-- For scaled, world-aligned tiles, scale and reposition the texture coordinates as needed.
		if tile.scale and tile.scale ~= 1 then
			face.tex_coords = meshport.scale_global_texture_coordinates(face.tex_coords, pos, sideIdx, tile.scale)
		end
	else
		-- If the tile isn't world-aligned, rotate it according to the facedir.
		face.tex_coords = meshport.rotate_texture_coordinates(face.tex_coords,
				meshport.facedir_to_tile_rotations[facedir][sideIdx])
	end

	return face
end

function meshport.get_def_from_id(contentId)
	return minetest.registered_nodes[minetest.get_name_from_content_id(contentId)] or {}
end

function meshport.get_aliased_drawtype(drawtype)
	return meshport.drawtype_aliases[drawtype or ""] or drawtype
end

function meshport.get_facedir(param2, type)
	if type == "facedir" or type == "colorfacedir" then
		-- For colorfacedir, only the first 5 bits are needed.
		return param2 % 32
	elseif type == "wallmounted" or type == "colorwallmounted" then
		-- For colorwallmounted, only the first 3 bits are needed. If the wallmounted direction is invalid, return 0.
		return meshport.wallmounted_to_facedir[param2 % 8] or 0
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
		neighbors[i] = array[area:indexp(vector.add(pos, meshport.neighbor_dirs[i]))]
	end

	return neighbors
end

function meshport.node_connects_to(nodeName, connectsTo)
	-- If `connectsTo` is a string or nil, turn it into a table for iteration.
	if type(connectsTo) ~= "table" then
		connectsTo = {connectsTo}
	end

	for _, connectName in ipairs(connectsTo) do
		if connectName == nodeName
				or string.sub(connectName, 1, 6) == "group:"
				and minetest.get_item_group(nodeName, string.sub(connectName, 7)) ~= 0 then
			return true
		end
	end

	return false
end

function meshport.get_tile(tiles, n)
	if type(tiles) == "table" then
		return tiles[n] or tiles[#tiles]
	else
		return "unknown"
	end
end

function meshport.get_asset_paths(assetFolderName, extension)
	local modAssetPath
	local assets = {}

	-- Iterate through each enabled mod.
	for _, modName in ipairs(minetest.get_modnames()) do
		modAssetPath = minetest.get_modpath(modName) .. DIR_DELIM .. assetFolderName

		-- Iterate through all the files in the requested folder of the mod.
		for _, fileName in ipairs(minetest.get_dir_list(modAssetPath, false)) do
			-- Add files to the table. If an extendion is specified, only add files with that extension.
			if not extension or string.lower(string.sub(fileName, -string.len(extension))) == extension then
				assets[fileName] = modAssetPath .. DIR_DELIM .. fileName
			end
		end
	end

	return assets
end
