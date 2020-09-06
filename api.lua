meshport.Faces = {}

function meshport.Faces:new()
	local o = {
		faces = {},
	}

	self.__index = self
	setmetatable(o, self)
	return o
end

function meshport.Faces:insert_face(face)
	table.insert(self.faces, face)
end

function meshport.Faces:copy()
	local newFaces = meshport.Faces:new()

	-- Using `table.copy` on all of `self.faces` does not work here.
	newFaces.faces = table.copy(self.faces)
	-- for _, face in ipairs(self.faces) do
	-- 	table.insert(newFaces.faces, table.copy(face))
	-- end

	return newFaces
end

function meshport.Faces:translate(vec)
	for _, face in ipairs(self.faces) do
		for i, vert in ipairs(face.verts) do
			face.verts[i] = vector.add(vert, vec)
		end
	end
end

function meshport.Faces:rotate_by_facedir(facedir)
	if facedir == 0 then
		return
	end

	for _, face in ipairs(self.faces) do
		-- Rotate vertices.
		for i = 1, #face.verts do
			face.verts[i] = meshport.rotate_vector_by_facedir(face.verts[i], facedir)
		end

		-- Rotate vertex normals.
		for i = 1, #face.vert_norms do
			face.vert_norms[i] = meshport.rotate_vector_by_facedir(face.vert_norms[i], facedir)
		end
	end
end

function meshport.Faces:apply_tiles(nodeDef)
	local tile

	for _, face in ipairs(self.faces) do
		tile = meshport.get_tile(nodeDef.tiles, face.tile_idx)
		face.texture = tile.name or tile
	end
end

meshport.Mesh = {}

function meshport.Mesh:new()
	local o = {
		verts = {},
		vert_norms = {},
		tex_coords = {},
		faces = {},
	}

	setmetatable(o, self)
	self.__index = self
	return o
end

function meshport.Mesh:insert_face(face)
	local indices = {
		verts = {},
		vert_norms = {},
		tex_coords = {},
	}

	local elementStr, vec

	-- Add vertices to mesh.
	for i, vert in ipairs(face.verts) do
		-- Invert Z axis to comply with Blender's coordinate system.
		vec = meshport.clean_vector({x = vert.x, y = vert.y, z = -vert.z})
		elementStr = string.format("v %f %f %f\n", vec.x, vec.y, vec.z)
		indices.verts[i] = meshport.find_or_insert(self.verts, elementStr)
	end

	-- Add texture coordinates (UV map).
	for i, texCoord in ipairs(face.tex_coords) do
		elementStr = string.format("vt %f %f\n", texCoord.x, texCoord.y)
		indices.tex_coords[i] = meshport.find_or_insert(self.tex_coords, elementStr)
	end

	-- Add vertex normals.
	for i, vertNorm in ipairs(face.vert_norms) do
		-- Invert Z axis.
		vec = meshport.clean_vector({x = vertNorm.x, y = vertNorm.y, z = -vertNorm.z})
		elementStr = string.format("vn %f %f %f\n", vec.x, vec.y, vec.z)
		indices.vert_norms[i] = meshport.find_or_insert(self.vert_norms, elementStr)
	end

	-- Add faces to mesh.
	local vertStrs = {}
	local vertList = {}

	for i = 1, #indices.verts do
		vertList = table.insert(vertStrs, table.concat({
				indices.verts[i],
				-- If there is a vertex normal but not a texture coordinate, insert a blank string here.
				indices.tex_coords[i] or (indices.vert_norms[i] and ""),
				indices.vert_norms[i],
			}, "/"))
	end

	self.faces[face.texture] = self.faces[face.texture] or {}
	table.insert(self.faces[face.texture], string.format("f %s\n", table.concat(vertStrs, " ")))
end

function meshport.Mesh:write_obj(path)
	local objFile = io.open(path .. DIR_DELIM .. "/model.obj", "w")

	objFile:write("# Created using meshport (https://github.com/random-geek/meshport).\n")
	objFile:write("mtllib materials.mtl\n")

	-- Write vertices.
	for _, vert in ipairs(self.verts) do
		objFile:write(vert)
	end

	-- Write texture coordinates.
	for _, texCoord in ipairs(self.tex_coords) do
		objFile:write(texCoord)
	end

	-- Write vertex normals.
	for _, vertNorm in ipairs(self.vert_norms) do
		objFile:write(vertNorm)
	end

	-- Write faces, sorted in order of material.
	for mat, faces in pairs(self.faces) do
		objFile:write(string.format("usemtl %s\n", mat))

		for _, face in ipairs(faces) do
			objFile:write(face)
		end
	end

	objFile:close()
end

function meshport.Mesh:write_mtl(path, playerName)
	local textures = meshport.get_asset_paths("textures")
	local matFile = io.open(path .. "/materials.mtl", "w")

	matFile:write("# Created using meshport (https://github.com/random-geek/meshport).\n\n")

	-- Write material information.
	for mat, _ in pairs(self.faces) do
		matFile:write(string.format("newmtl %s\n", mat))

		-- Attempt to get the base texture, ignoring texture modifiers.
		local texName = string.match(mat, "[%w%s%-_%.]+%.png") or mat

		if textures[texName] then
			if texName ~= mat then
				meshport.print(playerName, "warning", string.format("Ignoring texture modifers in material %q.", mat))
			end

			matFile:write(string.format("map_Kd %s\n\n", textures[texName]))
		else
			meshport.print(playerName, "warning",
					string.format("Could not find texture %q. Using a dummy material instead.", texName))
			matFile:write(string.format("Kd %f %f %f\n\n", math.random(), math.random(), math.random()))
		end

		matFile:write("\n\n")
	end

	matFile:close()
end
