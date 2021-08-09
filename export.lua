--[[
	Copyright (C) 2021 random-geek (https://github.com/random-geek)
	Minetest: Copyright (C) 2010-2021 celeron55, Perttu Ahola <celeron55@gmail.com>

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

-- Much of the mesh generation code in this file is derived from Minetest's
-- MapblockMeshGenerator class. See minetest/src/client/content_mapblock.cpp.

local S = meshport.S
local vec = vector.new -- Makes defining tables of vertices a little less painful.

--[[
	THE CUBIC NODE PRIORITY SYSTEM

	For each face on each cubic node, Meshport decides whether or not to draw
	that face based on a combination of the current node's drawtype (show in
	the top row of the table below), the neighboring node's drawtype (shown in
	the leftmost column), the direction of the face, and both nodes'
	visual_scale.

	A "YES" combination means the face is drawn, "no" means the face is not
	drawn, and "Offset" means the face is drawn, but slightly inset to avoid
	duplication of faces.

	|  This node => | allfaces (1) | glasslike | liquid  | normal (2) |
	|--------------:|:------------:|:---------:|:-------:|:----------:|
	| air/non-cubic | YES          | YES       | YES (3) | YES        |
	|      allfaces | (4)          | YES       | YES     | YES        |
	|     glasslike | Offset       | (5)       | YES     | YES        |
	|        liquid | Offset       | Offset    | no      | YES        |
	|    normal (2) | no           | no        | no      | no         |

	1. Allfaces faces are always drawn if `visual_scale` is not 1.
	2. The base of `plantlike_rooted` is treated as a normal node.
	3. Liquid faces are not drawn bordering a corresponding flowing liquid.
	4. Only drawn if facing X+, Y+, or Z+, or if either node's `visual_scale`
	   is not 1.
	5. Only drawn if the nodes are different. X-, Z-, and Y- faces are offset.
]]

local CUBIC_FACE_PRIORITY = {
	allfaces = 1,
	glasslike = 2,
	liquid = 3,
	normal = 4,
	plantlike_rooted = 4, -- base of plantlike_rooted is equivalent to `normal`.
}

local CUBIC_SIDE_FACES = {
	{vec(-0.5,  0.5, -0.5), vec( 0.5,  0.5, -0.5), vec( 0.5,  0.5,  0.5), vec(-0.5,  0.5,  0.5)}, -- Y+
	{vec(-0.5, -0.5,  0.5), vec( 0.5, -0.5,  0.5), vec( 0.5, -0.5, -0.5), vec(-0.5, -0.5, -0.5)}, -- Y-
	{vec( 0.5, -0.5, -0.5), vec( 0.5, -0.5,  0.5), vec( 0.5,  0.5,  0.5), vec( 0.5,  0.5, -0.5)}, -- X+
	{vec(-0.5, -0.5,  0.5), vec(-0.5, -0.5, -0.5), vec(-0.5,  0.5, -0.5), vec(-0.5,  0.5,  0.5)}, -- X-
	{vec( 0.5, -0.5,  0.5), vec(-0.5, -0.5,  0.5), vec(-0.5,  0.5,  0.5), vec( 0.5,  0.5,  0.5)}, -- Z+
	{vec(-0.5, -0.5, -0.5), vec( 0.5, -0.5, -0.5), vec( 0.5,  0.5, -0.5), vec(-0.5,  0.5, -0.5)}, -- Z-
}


-- For normal, plantlike_rooted, and liquid drawtypes
local function create_cubic_node(pos, content, param2, nodeDef, drawtype, neighbors)
	local facedir = meshport.get_facedir(nodeDef.paramtype2, param2)
	local selfPriority = CUBIC_FACE_PRIORITY[drawtype]
	-- If the current node is a liquid, get the flowing version of it.
	local flowingLiquid = drawtype == "liquid"
		and meshport.get_content_id_or_nil(nodeDef.liquid_alternative_flowing) or nil

	local faces = meshport.Faces:new()

	for i = 1, 6 do
		local drawFace

		if neighbors[i] == minetest.CONTENT_AIR then
			drawFace = true
		elseif neighbors[i] == minetest.CONTENT_IGNORE
				-- Don't draw faces between identical nodes
				or neighbors[i] == content
				-- Don't draw liquid faces bordering a corresponding flowing liquid
				or neighbors[i] == flowingLiquid then
			drawFace = false
		else
			local neighborDef = meshport.get_def_from_id(neighbors[i])
			local neighborDrawtype = meshport.get_aliased_drawtype(neighborDef.drawtype)
			drawFace = selfPriority > (CUBIC_FACE_PRIORITY[neighborDrawtype] or 0)
		end

		if drawFace then
			local norm = meshport.NEIGHBOR_DIRS[i]

			faces:insert_face(meshport.prepare_cuboid_face({
				verts = table.copy(CUBIC_SIDE_FACES[i]),
				vert_norms = {norm, norm, norm, norm},
				tex_coords = {{x = 0, y = 0}, {x = 1, y = 0}, {x = 1, y = 1}, {x = 0, y = 1}},
			}, nodeDef.tiles, pos, facedir, i))
		end
	end

	return faces
end


-- For allfaces and glasslike drawtypes, and equivalent variants.
local function create_special_cubic_node(pos, content, nodeDef, drawtype, neighbors)
	local selfPriority = CUBIC_FACE_PRIORITY[drawtype]
	local isAllfaces = drawtype == "allfaces"
	local allfacesScale = isAllfaces and nodeDef.visual_scale or 1

	local faces = meshport.Faces:new()

	for i = 1, 6 do
		local drawFace
		local inset = false

		if allfacesScale ~= 1 or neighbors[i] == minetest.CONTENT_AIR or neighbors[i] == minetest.CONTENT_IGNORE then
			drawFace = true
		elseif neighbors[i] == content then
			drawFace = isAllfaces and i % 2 == 1
		else
			local neighborDef = meshport.get_def_from_id(neighbors[i])
			local neighborDrawtype = meshport.get_aliased_drawtype(neighborDef.drawtype)
			local neighborPriority = CUBIC_FACE_PRIORITY[neighborDrawtype] or 0

			if neighborPriority < selfPriority then
				drawFace = true
			elseif neighborPriority >= 4 then
				-- Don't draw faces bordering normal nodes.
				drawFace = false
			elseif neighborPriority > selfPriority then
				drawFace = true
				inset = true
			elseif isAllfaces then -- neighborPriority == selfPriority
				drawFace = i % 2 == 1 or neighborDef.visual_scale ~= 1
			else -- neighborPriority == selfPriority
				drawFace = true
				inset = i % 2 == 0
			end
		end

		if drawFace then
			local verts = table.copy(CUBIC_SIDE_FACES[i])

			if inset then
				local offset = vector.multiply(meshport.NEIGHBOR_DIRS[i], -0.003)
				for j, vert in ipairs(verts) do
					verts[j] = vector.add(vert, offset)
				end
			end

			local norm = meshport.NEIGHBOR_DIRS[i]
			faces:insert_face(meshport.prepare_cuboid_face({
				verts = verts,
				vert_norms = {norm, norm, norm, norm},
				tex_coords = {{x = 0, y = 0}, {x = 1, y = 0}, {x = 1, y = 1}, {x = 0, y = 1}},
				tile_idx = 1, -- Only the first tile is used.
			}, nodeDef.tiles, pos, 0, i))
		end
	end

	faces:scale(allfacesScale)
	return faces
end


local GLASSLIKE_FRAMED_CONSTANTS = (function()
	local a = 0.5
	local g = 0.5 - 0.003
	local b = 0.876 * 0.5

	return {
		G = g,
		B = b,
		FRAME_EDGES = {
			{ b,  b, -a,  a,  a,  a}, -- Y+ / X+
			{-a,  b, -a, -b,  a,  a}, -- Y+ / X-
			{ b, -a, -a,  a, -b,  a}, -- Y- / X+
			{-a, -a, -a, -b, -b,  a}, -- Y- / X-
			{ b, -a,  b,  a,  a,  a}, -- X+ / Z+
			{ b, -a, -a,  a,  a, -b}, -- X+ / Z-
			{-a, -a,  b, -b,  a,  a}, -- X- / Z+
			{-a, -a, -a, -b,  a, -b}, -- X- / Z-
			{-a,  b,  b,  a,  a,  a}, -- Z+ / Y+
			{-a, -a,  b,  a, -b,  a}, -- Z+ / Y-
			{-a,  b, -a,  a,  a, -b}, -- Z- / Y+
			{-a, -a, -a,  a, -b, -b}, -- Z- / Y-
		},
		GLASS_FACES = {
			{vec(-a,  g, -a), vec( a,  g, -a), vec( a,  g,  a), vec(-a,  g,  a)}, -- Y+
			{vec(-a, -g,  a), vec( a, -g,  a), vec( a, -g, -a), vec(-a, -g, -a)}, -- Y-
			{vec( g, -a, -a), vec( g, -a,  a), vec( g,  a,  a), vec( g,  a, -a)}, -- X+
			{vec(-g, -a,  a), vec(-g, -a, -a), vec(-g,  a, -a), vec(-g,  a,  a)}, -- X-
			{vec( a, -a,  g), vec(-a, -a,  g), vec(-a,  a,  g), vec( a,  a,  g)}, -- Z+
			{vec(-a, -a, -g), vec( a, -a, -g), vec( a,  a, -g), vec(-a,  a, -g)}, -- Z-
		},
		EDGE_NEIGHBORS = {
			{1, 3,  8}, {1, 4,  7}, {2, 3, 16}, {2, 4, 15},
			{3, 5, 12}, {3, 6, 14}, {4, 5, 11}, {4, 6, 13},
			{5, 1,  9}, {5, 2, 17}, {6, 1, 10}, {6, 2, 18},
		},
	}
end)()


local function create_glasslike_framed_node(pos, param2, nodeDef, area, vContent)
	local idx = area:indexp(pos)
	local llParam2 = nodeDef.paramtype2 == "glasslikeliquidlevel" and param2 or 0
	local hMerge = llParam2 < 128 -- !(param2 & 128)
	local vMerge = llParam2 % 128 < 64 -- !(param2 & 64)
	local intLevel = llParam2 % 64

	-- Localize constants
	local G, B, FRAME_EDGES, GLASS_FACES, EDGE_NEIGHBORS = (function(c)
		return c.G, c.B, c.FRAME_EDGES, c.GLASS_FACES, c.EDGE_NEIGHBORS
	end)(GLASSLIKE_FRAMED_CONSTANTS)

	local neighbors = {
		false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false
	}

	if hMerge or vMerge then
		for i = 1, 18 do
			local dir = meshport.NEIGHBOR_DIRS[i]
			if (hMerge or (dir.x == 0 and dir.z == 0)) and (vMerge or dir.y == 0) then
				local nIdx = area:indexp(vector.add(pos, dir))
				neighbors[i] = vContent[nIdx] == vContent[idx]
			end
		end
	end

	local boxes = meshport.Boxes:new()

	for i = 1, 12 do
		local edgeVisible
		local touching = EDGE_NEIGHBORS[i]

		if neighbors[touching[3]] then
			edgeVisible = not (neighbors[touching[1]] and neighbors[touching[2]])
		else
			edgeVisible = neighbors[touching[1]] == neighbors[touching[2]]
		end

		if edgeVisible then
			boxes:insert_box(FRAME_EDGES[i])
		end
	end

	local faces = boxes:to_faces(nodeDef, pos, 0, 1)

	for i = 1, 6 do
		if not neighbors[i] then
			local norm = meshport.NEIGHBOR_DIRS[i]

			faces:insert_face({
				verts = table.copy(GLASS_FACES[i]),
				vert_norms = {norm, norm, norm, norm},
				tex_coords = {{x = 0, y = 0}, {x = 1, y = 0}, {x = 1, y = 1}, {x = 0, y = 1}},
				tile_idx = 2,
			})
		end
	end

	if intLevel > 0 and nodeDef.special_tiles and nodeDef.special_tiles[1] then
		local level = intLevel / 63 * 2 - 1
		local liquidBoxes = meshport.Boxes:new()
		liquidBoxes:insert_box({
			-(neighbors[4] and G or B),
			-(neighbors[2] and G or B),
			-(neighbors[6] and G or B),
			(neighbors[3] and G or B),
			(neighbors[1] and G or B) * level,
			(neighbors[5] and G or B)
		})
		faces:insert_all(liquidBoxes:to_faces(nodeDef, pos, 0, 1, true))
	end

	return faces
end


local FLOWING_LIQUID_CONSTANTS = {
	SIDE_DIRS = {vec(1, 0, 0), vec(-1, 0, 0), vec(0, 0, 1), vec(0, 0, -1)},
	SIDE_CORNERS = {
		{{x = 1, z = 1}, {x = 1, z = 0}}, -- X+
		{{x = 0, z = 0}, {x = 0, z = 1}}, -- X-
		{{x = 0, z = 1}, {x = 1, z = 1}}, -- Z+
		{{x = 1, z = 0}, {x = 0, z = 0}}, -- Z-
	},
}


local function create_flowing_liquid_node(pos, nodeDef, area, vContent, vParam2)
	local cSource = meshport.get_content_id_or_nil(nodeDef.liquid_alternative_source)
	local cFlowing = meshport.get_content_id_or_nil(nodeDef.liquid_alternative_flowing)
	local range = math.min(math.max(meshport.get_def_from_id(cFlowing).liquid_range or 8, 1), 8)

	--[[ Step 1: Gather neighbor data ]]
	local neighbors = {[-1] = {}, [0] = {}, [1] = {}}

	for dz = -1, 1 do
		for dx = -1, 1 do
			local nPos = vector.add(pos, vector.new(dx, 0, dz))
			local nIdx = area:indexp(nPos)

			neighbors[dz][dx] = {
				content = vContent[nIdx],
				level = -0.5,
				is_same_liquid = false,
				top_is_same_liquid = false,
			}
			local nData = neighbors[dz][dx]

			if vContent[nIdx] ~= minetest.CONTENT_IGNORE then
				if vContent[nIdx] == cSource then
					nData.is_same_liquid = true
					nData.level = 0.5
				elseif vContent[nIdx] == cFlowing then
					nData.is_same_liquid = true
					local intLevel = math.max(vParam2[nIdx] % 8 - 8 + range, 0)
					nData.level = -0.5 + (intLevel + 0.5) / range
				end

				local tPos = vector.add(nPos, vector.new(0, 1, 0))
				local tIdx = area:indexp(tPos)
				if vContent[tIdx] == cSource or vContent[tIdx] == cFlowing then
					nData.top_is_same_liquid = true
				end
			end
		end
	end

	--[[ Step 2: Determine level at each corner ]]
	local cornerLevels = {[0] = {[0] = 0, 0}, {[0] = 0, 0}}

	local function get_corner_level(cx, cz)
		local sum = 0
		local count = 0
		local airCount = 0

		for dz = -1, 0 do
			for dx = -1, 0 do
				local nData = neighbors[cz + dz][cx + dx]

				if nData.top_is_same_liquid or nData.content == cSource then
					return 0.5
				elseif nData.content == cFlowing then
					sum = sum + nData.level
					count = count + 1
				elseif nData.content == minetest.CONTENT_AIR then
					airCount = airCount + 1

					if airCount >= 2 then
						return -0.5 + 0.02
					end
				end
			end
		end

		if count > 0 then
			return sum / count
		end

		return 0
	end

	for cz = 0, 1 do
		for cx = 0, 1 do
			cornerLevels[cz][cx] = get_corner_level(cx, cz)
		end
	end

	--[[ Step 3: Actually create the liquid mesh ]]
	local faces = meshport.Faces:new()

	-- Localize constants
	local SIDE_DIRS, SIDE_CORNERS = (function(c)
		return c.SIDE_DIRS, c.SIDE_CORNERS
	end)(FLOWING_LIQUID_CONSTANTS)

	-- Add side faces
	local sideVerts = {
		{vec( 0.5, 0.5,  0.5), vec( 0.5, 0.5, -0.5), vec( 0.5, -0.5, -0.5), vec( 0.5, -0.5,  0.5)}, -- X+
		{vec(-0.5, 0.5, -0.5), vec(-0.5, 0.5,  0.5), vec(-0.5, -0.5,  0.5), vec(-0.5, -0.5, -0.5)}, -- X-
		{vec(-0.5, 0.5,  0.5), vec( 0.5, 0.5,  0.5), vec( 0.5, -0.5,  0.5), vec(-0.5, -0.5,  0.5)}, -- Z+
		{vec( 0.5, 0.5, -0.5), vec(-0.5, 0.5, -0.5), vec(-0.5, -0.5, -0.5), vec( 0.5, -0.5, -0.5)}, -- Z-
	}

	local function need_side(dir)
		local neighbor = neighbors[dir.z][dir.x]
		if neighbor.is_same_liquid
				and (not neighbors[0][0].top_is_same_liquid or neighbor.top_is_same_liquid) then
			return false
		end

		local nContent = neighbors[dir.z][dir.x].content
		local drawtype = meshport.get_aliased_drawtype(meshport.get_def_from_id(nContent).drawtype)
		if (CUBIC_FACE_PRIORITY[drawtype] or 0) >= 4 then
			return false -- Don't draw bordering normal nodes
		end

		return true
	end

	for i = 1, 4 do
		local dir = SIDE_DIRS[i]

		if need_side(dir) then
			local verts = sideVerts[i]
			local sideTexCoords = {{x = 1, y = 1}, {x = 0, y = 1}, {x = 0, y = 0}, {x = 1, y = 0}}

			if not neighbors[0][0].top_is_same_liquid then -- If there's liquid above, default to a full block.
				local corners = SIDE_CORNERS[i]

				for j = 1, 2 do
					local corner = cornerLevels[corners[j].z][corners[j].x]
					verts[j].y = corner
					sideTexCoords[j].y = corner + 0.5
				end
			end

			faces:insert_face({
				verts = verts,
				vert_norms = {dir, dir, dir, dir},
				tex_coords = sideTexCoords,
				tile_idx = 2,
				use_special_tiles = true,
			})
		end
	end

	-- Add top faces
	if not neighbors[0][0].top_is_same_liquid then -- Check node above the current node
		local verts = {
			vec( 0.5, cornerLevels[0][1], -0.5),
			vec( 0.5, cornerLevels[1][1],  0.5),
			vec(-0.5, cornerLevels[1][0],  0.5),
			vec(-0.5, cornerLevels[0][0], -0.5),
		}

		local norm1 = vector.normalize(vector.cross(
			vector.subtract(verts[1], verts[2]),
			vector.subtract(verts[3], verts[2])
		))
		local norm2 = vector.normalize(vector.cross(
			vector.subtract(verts[3], verts[4]),
			vector.subtract(verts[1], verts[4])
		))

		local dz = (cornerLevels[0][0] + cornerLevels[0][1]) -
			(cornerLevels[1][0] + cornerLevels[1][1])
		local dx = (cornerLevels[0][0] + cornerLevels[1][0]) -
			(cornerLevels[0][1] + cornerLevels[1][1])
		local textureAngle = -math.atan2(dz, dx)

		-- Get texture coordinate offset based on position.
		local tx, ty = pos.z, -pos.x
		-- Rotate offset around (0, 0) by textureAngle.
		-- Then isolate the fractional part, since the texture is tiled anyway.
		local sinTA = math.sin(textureAngle)
		local cosTA = math.cos(textureAngle)
		local textureOffset = {
			x = (tx * cosTA - ty * sinTA) % 1,
			y = (tx * sinTA + ty * cosTA) % 1
		}

		faces:insert_face({
			verts = {verts[1], verts[2], verts[3]},
			vert_norms = {norm1, norm1, norm1},
			tex_coords = meshport.translate_texture_coordinates(
				meshport.rotate_texture_coordinates_rad(
					{{x = 0, y = 0}, {x = 1, y = 0}, {x = 1, y = 1}},
					textureAngle
				),
				textureOffset
			),
			tile_idx = 1,
			use_special_tiles = true,
		})
		faces:insert_face({
			verts = {verts[3], verts[4], verts[1]},
			vert_norms = {norm2, norm2, norm2},
			tex_coords = meshport.translate_texture_coordinates(
				meshport.rotate_texture_coordinates_rad(
					{{x = 1, y = 1}, {x = 0, y = 1}, {x = 0, y = 0}},
					textureAngle
				),
				textureOffset
			),
			tile_idx = 1,
			use_special_tiles = true,
		})
	end

	-- Add bottom face
	local function need_liquid_bottom()
		local bContent = vContent[area:indexp(vector.add(pos, vector.new(0, -1, 0)))]
		if bContent == cSource or bContent == cFlowing then
			return false
		end

		local drawtype = meshport.get_aliased_drawtype(meshport.get_def_from_id(bContent).drawtype)
		if (CUBIC_FACE_PRIORITY[drawtype] or 0) >= 4 then
			return false -- Don't draw bordering normal nodes
		end

		return true
	end

	if need_liquid_bottom() then
		local norm = vector.new(0, -1, 0)

		faces:insert_face({
			verts = {
				vec(-0.5, -0.5,  0.5),
				vec( 0.5, -0.5,  0.5),
				vec( 0.5, -0.5, -0.5),
				vec(-0.5, -0.5, -0.5),
			},
			vert_norms = {norm, norm, norm, norm},
			tex_coords = {{x = 0, y = 0}, {x = 1, y = 0}, {x = 1, y = 1}, {x = 0, y = 1}},
			tile_idx = 1,
			use_special_tiles = true,
		})
	end

	return faces
end


local function create_nodebox_node(pos, content, param2, neighbors)
	local nodeName = minetest.get_name_from_content_id(content)
	local nodeDef = minetest.registered_nodes[nodeName]

	if not meshport.nodebox_cache[nodeName] then
		meshport.nodebox_cache[nodeName] = meshport.prepare_nodebox(nodeDef.node_box)
	end

	local facedir = meshport.get_facedir(nodeDef.paramtype2, param2)
	local boxes = meshport.collect_boxes(meshport.nodebox_cache[nodeName], nodeDef, param2, facedir, neighbors)

	if meshport.nodebox_cache[nodeName].type ~= "connected" then
		boxes:rotate_by_facedir(facedir)
	end

	return boxes:to_faces(nodeDef, pos, facedir)
end


local function create_mesh_node(nodeDef, param2, playerName)
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
				meshport.log(playerName, "warning", S("Mesh \"@1\" is not supported.", meshName))
			else
				meshport.log(playerName, "warning", S("Mesh \"@1\" could not be found.", meshName))
			end

			-- Cache a blank faces object so the player isn't warned again.
			meshport.mesh_cache[meshName] = meshport.Faces:new()
		else
			-- TODO: pcall this in case of failure
			local meshFaces = meshport.parse_obj(meshport.obj_paths[meshName])
			meshFaces:scale(nodeDef.visual_scale)
			meshport.mesh_cache[meshName] = meshFaces
		end
	end

	local faces = meshport.mesh_cache[meshName]:copy()

	local facedir = meshport.get_facedir(nodeDef.paramtype2, param2)
	faces:rotate_by_facedir(facedir)

	local rotation = meshport.get_degrotate(nodeDef.paramtype2, param2)
	faces:rotate_xz_degrees(rotation)

	return faces
end


-- Plant rotation is slightly different from normal wallmounted rotation.
local PLANTLIKE_WALLMOUNTED_TO_FACEDIR = {[0] = 20, 0, 16, 14, 11, 5}


local function create_plantlike_node(pos, param2, nodeDef)
	local isRooted = nodeDef.drawtype == "plantlike_rooted"
	local style = 0
	local height = 1.0
	local scale = 0.5 * nodeDef.visual_scale
	local rotation = meshport.get_degrotate(nodeDef.paramtype2, param2)
	local offset = vector.new(0, 0, 0)
	local randomOffsetY = false
	local faceNum = 0

	local faces = meshport.Faces:new()

	if isRooted then
		-- Place plant above the center node.
		offset.y = 1
	end

	if nodeDef.paramtype2 == "meshoptions" then
		style = param2 % 8

		if param2 % 16 >= 8 then -- param2 & 8
			-- TODO: Use MT's seed generators
			local seed = (pos.x % 0xFF) * 0x100 + (pos.z % 0xFF) + (pos.y % 0xFF) * 0x10000
			local rng = PseudoRandom(seed)
			offset.x = ((rng:next() % 16) / 16) * 0.29 - 0.145
			offset.z = ((rng:next() % 16) / 16) * 0.29 - 0.145
		end

		if param2 % 32 >= 16 then -- param2 & 16
			scale = scale * 1.41421
		end

		if param2 % 64 >= 32 then -- param2 & 32
			randomOffsetY = true
		end
	elseif nodeDef.paramtype2 == "leveled" then
		height = param2 / 16
		if height == 0 then
			-- No height, no plant!
			-- But seriously, zero-area faces cause problems with Blender.
			return faces
		end
	end

	local function create_plantlike_quad(faceRotation, topOffset, bottomOffset)
		-- Use Faces, even though it's just one face.
		local face = meshport.Faces:new()
		local plantHeight = 2.0 * scale * height
		local norm = vector.normalize(vector.new(0, bottomOffset - topOffset, plantHeight))

		face:insert_face({
			verts = {
				vec(-scale, -0.5 + plantHeight, topOffset),
				vec( scale, -0.5 + plantHeight, topOffset),
				vec( scale, -0.5, bottomOffset),
				vec(-scale, -0.5, bottomOffset),
			},
			tex_coords = {{x = 0, y = 1}, {x = 1, y = 1}, {x = 1, y = 1 - height}, {x = 0, y = 1 - height}},
			vert_norms = {norm, norm, norm, norm},
			tile_idx = 0,
			use_special_tiles = isRooted,
		})
		face:rotate_xz_degrees(faceRotation + rotation)

		local faceOffset = vector.new(offset)
		if randomOffsetY then
			local seed = faceNum + (pos.x % 0xFF) * 0x10000 + (pos.z % 0xFF) * 0x100 + (pos.y % 0xFF) * 0x1000000
			local yRng = PseudoRandom(seed)
			faceOffset.y = faceOffset.y - ((yRng:next() % 16) / 16 * 0.125)
			faceNum = faceNum + 1
		end

		face:translate(faceOffset)
		return face
	end

	if style == 0 then
		faces:insert_all(create_plantlike_quad(46, 0, 0))
		faces:insert_all(create_plantlike_quad(-44, 0, 0))
	elseif style == 1 then
		faces:insert_all(create_plantlike_quad(91, 0, 0))
		faces:insert_all(create_plantlike_quad(1, 0, 0))
	elseif style == 2 then
		faces:insert_all(create_plantlike_quad(121, 0, 0))
		faces:insert_all(create_plantlike_quad(241, 0, 0))
		faces:insert_all(create_plantlike_quad(1, 0, 0))
	elseif style == 3 then
		faces:insert_all(create_plantlike_quad(1, 0.25, 0.25))
		faces:insert_all(create_plantlike_quad(91, 0.25, 0.25))
		faces:insert_all(create_plantlike_quad(181, 0.25, 0.25))
		faces:insert_all(create_plantlike_quad(271, 0.25, 0.25))
	elseif style == 4 then
		faces:insert_all(create_plantlike_quad(1, -0.5, 0))
		faces:insert_all(create_plantlike_quad(91, -0.5, 0))
		faces:insert_all(create_plantlike_quad(181, -0.5, 0))
		faces:insert_all(create_plantlike_quad(271, -0.5, 0))
	end

	-- TODO: Support facedir if added.
	if nodeDef.paramtype2 == "wallmounted" or nodeDef.paramtype2 == "colorwallmounted" then
		local facedir = PLANTLIKE_WALLMOUNTED_TO_FACEDIR[param2 % 8] or 0
		faces:rotate_by_facedir(facedir)
	end

	return faces
end


local function create_node(idx, area, vContent, vParam2, playerName)
	if vContent[idx] == minetest.CONTENT_AIR
			or vContent[idx] == minetest.CONTENT_IGNORE
			or vContent[idx] == minetest.CONTENT_UNKNOWN then -- TODO: Export unknown nodes?
		return
	end

	local nodeDef = meshport.get_def_from_id(vContent[idx])
	if nodeDef.drawtype == "airlike" then
		return
	end

	local pos = area:position(idx)
	local nodeDrawtype = meshport.get_aliased_drawtype(nodeDef.drawtype)
	local neighbors, faces

	if CUBIC_FACE_PRIORITY[nodeDrawtype] or nodeDrawtype == "nodebox" then
		neighbors = meshport.get_node_neighbors(vContent, area, idx)
	end

	if (CUBIC_FACE_PRIORITY[nodeDrawtype] or 0) >= 3 then -- liquid, normal, plantlike_rooted
		faces = create_cubic_node(pos, vContent[idx], vParam2[idx], nodeDef, nodeDrawtype, neighbors)

		if nodeDrawtype == "plantlike_rooted" then
			local plantPos = vector.add(pos, vector.new(0, 1, 0))
			local plantFaces = create_plantlike_node(plantPos, vParam2[idx], nodeDef)
			faces:insert_all(plantFaces)
		end
	elseif CUBIC_FACE_PRIORITY[nodeDrawtype] then -- Any other cubic nodes (allfaces, glasslike)
		faces = create_special_cubic_node(pos, vContent[idx], nodeDef, nodeDrawtype, neighbors)
	elseif nodeDrawtype == "glasslike_framed" then
		faces = create_glasslike_framed_node(pos, vParam2[idx], nodeDef, area, vContent)
	elseif nodeDrawtype == "flowingliquid" then
		faces = create_flowing_liquid_node(pos, nodeDef, area, vContent, vParam2)
	elseif nodeDrawtype == "nodebox" then
		faces = create_nodebox_node(pos, vContent[idx], vParam2[idx], neighbors)
	elseif nodeDrawtype == "mesh" then
		faces = create_mesh_node(nodeDef, vParam2[idx], playerName)
	elseif nodeDrawtype == "plantlike" then
		faces = create_plantlike_node(pos, vParam2[idx], nodeDef)
	end

	if not faces then
		return
	end

	faces:apply_tiles(nodeDef)
	return faces
end


local function initialize_resources()
	meshport.texture_paths = meshport.get_asset_paths("textures")
	meshport.texture_dimension_cache = {}
	-- meshport.obj_paths is only loaded if needed
	meshport.nodebox_cache = {}
	meshport.mesh_cache = {}
end


local function cleanup_resources()
	meshport.texture_paths = nil
	meshport.texture_dimension_cache = nil
	meshport.obj_paths = nil
	meshport.nodebox_cache = nil
	meshport.mesh_cache = nil
end


function meshport.create_mesh(playerName, p1, p2, path)
	meshport.log(playerName, "info", S("Generating mesh..."))
	initialize_resources()

	p1, p2 = vector.sort(p1, p2)
	local vm = minetest.get_voxel_manip()

	-- Add one node of padding to area so we can read neighbor blocks.
	local vp1, vp2 = vm:read_from_map(vector.subtract(p1, 1), vector.add(p2, 1))
	local vContent = vm:get_data()
	local vParam2 = vm:get_param2_data()

	-- Create a VoxelArea for converting from flat array indices to position vectors.
	local vArea = VoxelArea:new{MinEdge = vp1, MaxEdge = vp2}
	local meshOrigin = vector.subtract(p1, 0.5)
	local mesh = meshport.Mesh:new()

	-- Loop through all positions in the desired area.
	for idx in vArea:iterp(p1, p2) do
		-- Generate a mesh for the node.
		local faces = create_node(idx, vArea, vContent, vParam2, playerName)

		if faces then
			-- Move the node to its proper position.
			faces:translate(vector.subtract(vArea:position(idx), meshOrigin))

			-- Add faces to our final mesh.
			mesh:insert_faces(faces)
		end
	end

	minetest.mkdir(path)
	mesh:write_obj(path)
	mesh:write_mtl(path, playerName)

	cleanup_resources()
	meshport.log(playerName, "info", S("Finished. Saved to @1", path))
end
