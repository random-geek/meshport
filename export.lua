meshport.nodebox_cache = {}
meshport.mesh_cache = {}

meshport.cube_face_priority = {
	allfaces = 1,
	glasslike_framed = 2,
	glasslike = 3,
	normal = 4,
}

function meshport.create_cube_node(nodeDrawtype, nodeTiles, pos, facedir, neighbors)
	local sideFaces = {
		{{x = 0.5, y = 0.5, z =-0.5}, {x = 0.5, y = 0.5, z = 0.5}, {x =-0.5, y = 0.5, z = 0.5}, {x =-0.5, y = 0.5, z =-0.5}}, -- Y+
		{{x = 0.5, y =-0.5, z = 0.5}, {x = 0.5, y =-0.5, z =-0.5}, {x =-0.5, y =-0.5, z =-0.5}, {x =-0.5, y =-0.5, z = 0.5}}, -- Y-
		{{x = 0.5, y =-0.5, z = 0.5}, {x = 0.5, y = 0.5, z = 0.5}, {x = 0.5, y = 0.5, z =-0.5}, {x = 0.5, y =-0.5, z =-0.5}}, -- X+
		{{x =-0.5, y =-0.5, z =-0.5}, {x =-0.5, y = 0.5, z =-0.5}, {x =-0.5, y = 0.5, z = 0.5}, {x =-0.5, y =-0.5, z = 0.5}}, -- X-
		{{x =-0.5, y =-0.5, z = 0.5}, {x =-0.5, y = 0.5, z = 0.5}, {x = 0.5, y = 0.5, z = 0.5}, {x = 0.5, y =-0.5, z = 0.5}}, -- Z+
		{{x = 0.5, y =-0.5, z =-0.5}, {x = 0.5, y = 0.5, z =-0.5}, {x =-0.5, y = 0.5, z =-0.5}, {x =-0.5, y =-0.5, z =-0.5}}, -- Z-
	}

	local texCoords = {{x = 1, y = 0}, {x = 1, y = 1}, {x = 0, y = 1}, {x = 0, y = 0}}

	local faces = meshport.Faces:new()
	-- For glasslike_framed nodes, only the first tile is used.
	local tileIdx = nodeDrawtype == "glasslike_framed" and 1 or nil
	local neighborDrawtype, vertNorm

	for i = 1, 6 do
		neighborDrawtype = meshport.get_aliased_drawtype(meshport.get_def_from_id(neighbors[i]).drawtype)

		if meshport.cube_face_priority[nodeDrawtype] > (meshport.cube_face_priority[neighborDrawtype] or 0)
				-- For allfaces nodes (such are leaves), interior faces are drawn only when facing X+, Y+, or Z+.
				or (nodeDrawtype == "allfaces" and neighborDrawtype == "allfaces" and i % 2 == 1) then
			vertNorm = meshport.neighbor_dirs[i]

			faces:insert_face(meshport.prepare_cuboid_face({
				verts = sideFaces[i],
				tex_coords = texCoords,
				vert_norms = {vertNorm, vertNorm, vertNorm, vertNorm},
				tile_idx = tileIdx,
			}, nodeTiles, pos, facedir, i))
		end
	end

	return faces
end

function meshport.create_nodebox_node(nodeName, pos, facedir, param2, neighbors)
	local nodeDef = minetest.registered_nodes[nodeName]

	if not meshport.nodebox_cache[nodeName] then
		meshport.nodebox_cache[nodeName] = meshport.prepare_nodebox(nodeDef.node_box)
	end

	local boxes = meshport.collect_boxes(meshport.nodebox_cache[nodeName], nodeDef, facedir, param2, neighbors)

	if meshport.nodebox_cache[nodeName].type ~= "connected" then
		boxes:rotate_by_facedir(facedir)
	end

	return boxes:to_faces(nodeDef.tiles, pos, facedir)
end

function meshport.create_mesh_node(nodeDef, playerName)
	local meshName = nodeDef.mesh

	if not meshName then
		return
	end

	if not meshport.mesh_cache[meshName] then
		-- Get the paths of all .obj meshes.
		if not meshport.obj_paths then
			meshport.obj_paths = meshport.get_asset_paths("models", ".obj")
		end

		if not meshport.obj_paths[meshName] then
			if string.lower(string.sub(meshName, -4)) ~= ".obj" then
				meshport.print(playerName, "warning", string.format("Mesh %q is not supported.", meshName))
			else
				meshport.print(playerName, "warning", string.format("Mesh %q could not be found.", meshName))
			end

			-- Cache a blank faces object so the player isn't warned again.
			meshport.mesh_cache[meshName] = meshport.Faces:new()
		else
			meshport.mesh_cache[meshName] = meshport.parse_obj(meshport.obj_paths[meshName])
		end
	end

	return meshport.mesh_cache[meshName]:copy()
end

function meshport.create_node(idx, area, content, param2, playerName)
	if content[idx] == minetest.CONTENT_AIR or content[idx] == minetest.CONTENT_IGNORE then
		return
	end

	local nodeDef = meshport.get_def_from_id(content[idx])

	if not nodeDef.drawtype or nodeDef.drawtype == "airlike" then
		return
	end

	local nodeDrawtype = meshport.get_aliased_drawtype(nodeDef.drawtype)
	local facedir = meshport.get_facedir(param2[idx], nodeDef.paramtype2)
	local isCubicType = meshport.cube_face_priority[nodeDrawtype] or nodeDrawtype == "nodebox"
	local neighbors, faces

	if isCubicType then
		neighbors = meshport.get_node_neighbors(content, area, idx)
	end

	if meshport.cube_face_priority[nodeDrawtype] then
		faces = meshport.create_cube_node(nodeDrawtype, nodeDef.tiles, area:position(idx), facedir, neighbors)
	elseif nodeDrawtype == "nodebox" then
		faces = meshport.create_nodebox_node(
				minetest.get_name_from_content_id(content[idx]), area:position(idx), facedir, param2[idx], neighbors)
	elseif nodeDrawtype == "mesh" then
		faces = meshport.create_mesh_node(nodeDef, playerName)
	end

	if not faces then
		return
	end

	if not isCubicType then
		faces:rotate_by_facedir(facedir)
	end

	faces:apply_tiles(nodeDef)
	return faces
end

function meshport.create_mesh(playerName, p1, p2, path)
	meshport.print(playerName, "info", "Generating mesh...")
	p1, p2 = vector.sort(p1, p2)
	local vm = minetest.get_voxel_manip()

	-- Add one node of padding to area so we can read neighbor blocks.
	local vp1, vp2 = vm:read_from_map(vector.subtract(p1, 1), vector.add(p2, 1))
	local content = vm:get_data()
	local param2 = vm:get_param2_data()

	-- Create a VoxelArea for converting from flat array indices to position vectors.
	local vArea = VoxelArea:new{MinEdge = vp1, MaxEdge = vp2}
	local mesh = meshport.Mesh:new()
	local faces

	-- Loop through all positions in the desired area.
	for idx in vArea:iterp(p1, p2) do
		-- Generate a mesh for the node.
		faces = meshport.create_node(idx, vArea, content, param2, playerName)

		if faces then
			-- Move the node to its proper position in the mesh.
			faces:translate(vector.add(vector.subtract(vArea:position(idx), p1), 0.5))

			for _, face in ipairs(faces.faces) do
				-- Add each face to our final mesh.
				mesh:insert_face(face)
			end
		end
	end

	minetest.mkdir(path)

	mesh:write_obj(path)
	mesh:write_mtl(path, playerName)

	meshport.print(playerName, "info", "Finished. Saved to " .. path)
end
