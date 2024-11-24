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


local SIDE_BOX_NAMES = {
	"top", -- Y+
	"bottom", -- Y-
	"right", -- X+
	"left", -- X-
	"back", -- Z+
	"front", -- Z-
}


local function sort_box(box)
	return {
		math.min(box[1], box[4]),
		math.min(box[2], box[5]),
		math.min(box[3], box[6]),
		math.max(box[1], box[4]),
		math.max(box[2], box[5]),
		math.max(box[3], box[6]),
	}
end


local function node_connects_to(nodeName, connectsTo)
	-- If `connectsTo` is a string or nil, turn it into a table for iteration.
	if type(connectsTo) ~= "table" then
		connectsTo = {connectsTo}
	end

	for _, connectName in ipairs(connectsTo) do
		if connectName == nodeName
				or string.sub(connectName, 1, 6) == "group:"
				and core.get_item_group(nodeName, string.sub(connectName, 7)) ~= 0 then
			return true
		end
	end

	return false
end


-- A list of node boxes, in the format used by Luanti:
-- {a.x, a.y, a.z, b.x, b.y, b.z}
-- Individual boxes inside the `boxes` array are not mutated.
meshport.Boxes = {}

function meshport.Boxes:new(boxes)
	local o = {}

	if type(boxes) == "table" and type(boxes[1]) == "table" then
		-- Copy boxes individually to avoid mutating the argument.
		o.boxes = {}
		for i, box in ipairs(boxes) do
			o.boxes[i] = box
		end
	else
		o.boxes = {boxes}
	end

	setmetatable(o, self)
	self.__index = self
	return o
end

function meshport.Boxes:insert_box(box)
	table.insert(self.boxes, box)
end

function meshport.Boxes:insert_all(boxes)
	for _, box in ipairs(boxes.boxes) do
		table.insert(self.boxes, box)
	end
end

function meshport.Boxes:transform(func)
	local a, b

	for i, box in ipairs(self.boxes) do
		a = func(vector.new(box[1], box[2], box[3]))
		b = func(vector.new(box[4], box[5], box[6]))

		self.boxes[i] = {a.x, a.y, a.z, b.x, b.y, b.z}
	end
end

function meshport.Boxes:rotate_by_facedir(facedir)
	local a, b

	for i, box in ipairs(self.boxes) do
		a = meshport.rotate_vector_by_facedir(vector.new(box[1], box[2], box[3]), facedir)
		b = meshport.rotate_vector_by_facedir(vector.new(box[4], box[5], box[6]), facedir)

		self.boxes[i] = {a.x, a.y, a.z, b.x, b.y, b.z}
	end
end

function meshport.Boxes:get_leveled(level)
	local newBoxes = meshport.Boxes:new()

	for i, box in ipairs(self.boxes) do
		local newBox = sort_box(box)
		newBox[5] = level / 64 - 0.5
		newBoxes.boxes[i] = newBox
	end

	return newBoxes
end

function meshport.Boxes:to_faces(nodeDef, pos, facedir, tileIdx, useSpecial)
	local tiles = useSpecial and nodeDef.special_tiles or nodeDef.tiles
	local vec = vector.new

	local faces = meshport.Faces:new()

	for _, box in ipairs(self.boxes) do
		local b = sort_box(box)

		local sideFaces = {
			{vec(b[1], b[5], b[3]), vec(b[4], b[5], b[3]), vec(b[4], b[5], b[6]), vec(b[1], b[5], b[6])}, -- Y+
			{vec(b[1], b[2], b[6]), vec(b[4], b[2], b[6]), vec(b[4], b[2], b[3]), vec(b[1], b[2], b[3])}, -- Y-
			{vec(b[4], b[2], b[3]), vec(b[4], b[2], b[6]), vec(b[4], b[5], b[6]), vec(b[4], b[5], b[3])}, -- X+
			{vec(b[1], b[2], b[6]), vec(b[1], b[2], b[3]), vec(b[1], b[5], b[3]), vec(b[1], b[5], b[6])}, -- X-
			{vec(b[4], b[2], b[6]), vec(b[1], b[2], b[6]), vec(b[1], b[5], b[6]), vec(b[4], b[5], b[6])}, -- Z+
			{vec(b[1], b[2], b[3]), vec(b[4], b[2], b[3]), vec(b[4], b[5], b[3]), vec(b[1], b[5], b[3])}, -- Z-
		}

		local t = {}
		for i = 1, 6 do
			t[i] = b[i] + 0.5 -- Texture coordinates range from 0 to 1
		end

		local sideTexCoords = {
			{{x =  t[1], y =  t[3]}, {x =  t[4], y =  t[3]}, {x =  t[4], y =  t[6]}, {x =  t[1], y =  t[6]}}, -- Y+
			{{x =  t[1], y =1-t[6]}, {x =  t[4], y =1-t[6]}, {x =  t[4], y =1-t[3]}, {x =  t[1], y =1-t[3]}}, -- Y-
			{{x =  t[3], y =  t[2]}, {x =  t[6], y =  t[2]}, {x =  t[6], y =  t[5]}, {x =  t[3], y =  t[5]}}, -- X+
			{{x =1-t[6], y =  t[2]}, {x =1-t[3], y =  t[2]}, {x =1-t[3], y =  t[5]}, {x =1-t[6], y =  t[5]}}, -- X-
			{{x =1-t[4], y =  t[2]}, {x =1-t[1], y =  t[2]}, {x =1-t[1], y =  t[5]}, {x =1-t[4], y =  t[5]}}, -- Z+
			{{x =  t[1], y =  t[2]}, {x =  t[4], y =  t[2]}, {x =  t[4], y =  t[5]}, {x =  t[1], y =  t[5]}}, -- Z-
		}

		for i = 1, 6 do
			local norm = meshport.NEIGHBOR_DIRS[i]

			faces:insert_face(meshport.prepare_cuboid_face({
				verts = sideFaces[i],
				tex_coords = sideTexCoords[i],
				vert_norms = {norm, norm, norm, norm},
				tile_idx = tileIdx,
				use_special_tiles = useSpecial,
			}, tiles, pos, facedir, i))
		end
	end

	return faces
end


function meshport.prepare_nodebox(nodebox)
	local prepNodebox = {}
	prepNodebox.type = nodebox.type

	if nodebox.type == "regular" then
		prepNodebox.fixed = meshport.Boxes:new({-0.5, -0.5, -0.5, 0.5, 0.5, 0.5})
	elseif nodebox.type == "fixed" or nodebox.type == "leveled" then
		prepNodebox.fixed = meshport.Boxes:new(nodebox.fixed)
	elseif nodebox.type == "connected" then
		prepNodebox.fixed = meshport.Boxes:new(nodebox.fixed)
		prepNodebox.connected = {}
		prepNodebox.disconnected = {}

		for i, name in ipairs(SIDE_BOX_NAMES) do
			prepNodebox.connected[i] = meshport.Boxes:new(nodebox["connect_" .. name])
			prepNodebox.disconnected[i] = meshport.Boxes:new(nodebox["disconnected_" .. name])
		end

		prepNodebox.disconnected_all = meshport.Boxes:new(nodebox.disconnected)
		prepNodebox.disconnected_sides = meshport.Boxes:new(nodebox.disconnected_sides)
	elseif nodebox.type == "wallmounted" then
		prepNodebox.wall_bottom = meshport.Boxes:new(nodebox.wall_bottom)
		prepNodebox.wall_top = meshport.Boxes:new(nodebox.wall_top)
		prepNodebox.wall_side = meshport.Boxes:new(nodebox.wall_side)

		-- Rotate the boxes so they are in the correct orientation after rotation by facedir.
		prepNodebox.wall_top:transform(function(v) return vector.new(-v.x, -v.y, v.z) end)
		prepNodebox.wall_side:transform(function(v) return vector.new(-v.z, v.x, v.y) end)
	end

	return prepNodebox
end


function meshport.collect_boxes(prepNodebox, nodeDef, param2, facedir, neighbors)
	local boxes = meshport.Boxes:new()

	if prepNodebox.fixed then
		if prepNodebox.type == "leveled" then
			local level = nodeDef.paramtype2 == "leveled" and param2 or nodeDef.leveled or 0
			boxes:insert_all(prepNodebox.fixed:get_leveled(level))
		else
			boxes:insert_all(prepNodebox.fixed)
		end
	end

	if prepNodebox.type == "connected" then
		local neighborName

		for i = 1, 6 do
			neighborName = core.get_name_from_content_id(neighbors[i])

			if node_connects_to(neighborName, nodeDef.connects_to) then
				boxes:insert_all(prepNodebox.connected[i])
			else
				boxes:insert_all(prepNodebox.disconnected[i])
			end
		end
	elseif prepNodebox.type == "wallmounted" then
		if nodeDef.paramtype2 == "wallmounted" or nodeDef.paramtype2 == "colorwallmounted" then
			if facedir == 20 then
				boxes:insert_all(prepNodebox.wall_top)
			elseif facedir == 0 then
				boxes:insert_all(prepNodebox.wall_bottom)
			else
				boxes:insert_all(prepNodebox.wall_side)
			end
		else
			boxes:insert_all(prepNodebox.wall_top)
		end
	end

	return boxes
end
