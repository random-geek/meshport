function meshport.parse_vector_element(elementStr)
	local elementType
	local vec = {}

	-- Get the element type and vector. `vec.z` will be left `nil` for two-dimensional vectors.
	elementType, vec.x, vec.y, vec.z = string.match(elementStr, "^(%a+)%s([%d%.%-]+)%s([%d%.%-]+)%s?([%d%.%-]*)")

	for k, v in pairs(vec) do
		vec[k] = tonumber(v)
	end

	-- Return the element type and value.
	if elementType == "v" then
		-- Invert X axis to match the Minetest coordinate system.
		vec.x = -vec.x
		return "verts", vec
	elseif elementType == "vt" then
		return "tex_coords", vec
	elseif elementType == "vn" then
		vec.x = -vec.x
		return "vert_norms", vec
	end
end

function meshport.parse_face_element(elements, elementStr)
	-- Split the face element into strings containing the indices of elements associated with each vertex.
	local vertStrs = string.split(string.match(elementStr, "^f%s([%d/%s]+)"), " ")
	local elementIndices

	local face = {
		verts = {},
		tex_coords = {},
		vert_norms = {},
	}

	for i, vertStr in ipairs(vertStrs) do
		-- Split the string into a table of indices for position, texture coordinate, and/or vertex normal elements.
		elementIndices = string.split(vertStr, "/", true)

		for k, v in pairs(elementIndices) do
			elementIndices[k] = tonumber(v)
		end

		-- Set the position, texture coordinate, and vertex normal of the face. `or 0` prevents a nil index error.
		face.verts[i] = elements.verts[elementIndices[1] or 0]
		face.tex_coords[i] = elements.tex_coords[elementIndices[2] or 0]
		face.vert_norms[i] = elements.vert_norms[elementIndices[3] or 0]
	end

	return face
end

function meshport.parse_obj(path)
	local faces = meshport.Faces:new()
	local file = io.open(path, "r")

	local elements = {
		verts = {},
		tex_coords = {},
		vert_norms = {},
	}

	local groups = {}
	local curGroup
	local elementType

	for line in file:lines() do
		elementType = string.sub(line, 1, 1)

		if elementType == "v" then
			-- Parse the vector element. Used for "v", "vt", and "vn".
			local type, value = meshport.parse_vector_element(line)
			table.insert(elements[type], value)
		elseif elementType == "f" then
			-- If the face is not part of any group, use the placeholder group `0`.
			if not curGroup then
				table.insert(groups, 0)
				curGroup = table.indexof(groups, 0)
			end

			-- Parse the face element.
			local face = meshport.parse_face_element(elements, line)
			-- Assign materials according to the group.
			face.tile_idx = curGroup
			faces:insert_face(face)
		elseif elementType == "g" then
			-- If this group has not been used yet, then add it to the list.
			curGroup = meshport.find_or_insert(groups, string.match(line, "^g%s(.+)"))
		end
	end

	return faces
end
