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

-- See the OBJ file specification: http://www.martinreddy.net/gfx/3d/OBJ.spec
-- Also, the Irrlicht implementation: irrlicht/source/Irrlicht/COBJMeshFileLoader.cpp


local function parse_vector_element(elementType, elementStr)
	if elementType == "v" or elementType == "vn" then
		-- Note that there may be an optional weight value after z, which is ignored.
		local xs, ys, zs = string.match(elementStr, "^([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)")
		-- The X axis of vectors is inverted to match the Luanti coordinate system.
		local vec = vector.new(-tonumber(xs), tonumber(ys), tonumber(zs))

		if elementType == "v" then
			return "verts", vec
		else
			return "vert_norms", vec
		end
	elseif elementType == "vt" then
		local xs, ys = string.match(elementStr, "^([%d%.%-]+)%s+([%d%.%-]+)")
		local coords = {x = tonumber(xs), y = tonumber(ys)}
		assert(coords.x and coords.y, "Invalid texture coordinate element")
		return "tex_coords", coords
	end
end


local function parse_face_element(elements, faceStr)
	-- Split the face element into strings containing the indices of elements associated with each vertex.
	local vertStrs = string.split(faceStr, " ")

	local face = {
		verts = {},
		tex_coords = {},
		vert_norms = {},
	}

	for i, vertStr in ipairs(vertStrs) do
		-- Split the string into indices for vertex, texture coordinate, and/or vertex normal elements.
		local vs, vts, vns = string.match(vertStr, "^(%d*)/?(%d*)/?(%d*)$")
		local vi, vti, vni = tonumber(vs), tonumber(vts), tonumber(vns)
		assert(vi, "Invalid face element")

		-- Set the position, texture coordinate, and vertex normal of the vertex.
		-- Note that vti or vni are allowed to be nil
		face.verts[i] = elements.verts[vi]
		face.tex_coords[i] = elements.tex_coords[vti]
		face.vert_norms[i] = elements.vert_norms[vni]
	end

	return face
end


local function handle_group(groups, elementStr)
	-- Note: Luanti ignores usemtl; see `OBJ_LOADER_IGNORE_MATERIAL_FILES`.
	-- The format allows multiple group names; get only the first one.
	local groupName = string.match(elementStr, "^(%S+)")
	if not groupName then
		-- "default" is the default group name if no name is specified.
		groupName = "default"
	end
	local groupIdx = table.indexof(groups, groupName)

	-- If this group has not been used yet, add it to the list.
	if groupIdx < 0 then
		table.insert(groups, groupName)
		groupIdx = #groups
	end

	return groupIdx
end


function meshport.parse_obj(path)
	local file = io.open(path, "r")

	local faces = meshport.Faces:new()
	local elements = {
		verts = {},
		tex_coords = {},
		vert_norms = {},
	}

	-- Tiles are assigned according to groups, in the order in which groups are defined.
	local groups = {}
	local currentTileIdx

	for line in file:lines() do
		-- elementStr may be an empty string, e.g. "g" with no group name.
		local elementType, elementStr = string.match(line, "^(%a+)%s*(.*)")

		if elementType == "v" or elementType == "vt" or elementType == "vn" then
			local dest, value = parse_vector_element(elementType, elementStr)
			table.insert(elements[dest], value)
		elseif elementType == "f" then
			-- If the face is not part of any group, use the placeholder group `0`.
			if not currentTileIdx then
				table.insert(groups, 0)
				currentTileIdx = #groups
			end

			-- Parse the face element.
			local face = parse_face_element(elements, elementStr)
			-- Assign materials according to the group.
			face.tile_idx = currentTileIdx
			faces:insert_face(face)
		elseif elementType == "g" then
			currentTileIdx = handle_group(groups, elementStr)
		end
	end

	return faces
end
