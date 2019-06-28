meshport.side_box_names = {
	"top", -- Y+
	"bottom", -- Y-
	"right", -- X+
	"left", -- X-
	"back", -- Z+
	"front", -- Z-
}

function meshport.sort_box(box)
	return {
		math.min(box[1], box[4]),
		math.min(box[2], box[5]),
		math.min(box[3], box[6]),
		math.max(box[1], box[4]),
		math.max(box[2], box[5]),
		math.max(box[3], box[6]),
	}
end

meshport.Boxes = {}

function meshport.Boxes:new(boxes)
	local o = {}

	if type(boxes) ~= "table" or type(boxes[1]) == "number" then
		o.boxes = {boxes}
	else
		o.boxes = boxes
	end

	setmetatable(o, self)
	self.__index = self
	return o
end

function meshport.Boxes:insert_all(boxes)
	for _, box in ipairs(boxes.boxes) do
		table.insert(self.boxes, table.copy(box))
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
	local newBoxes = meshport.Boxes:new(table.copy(self.boxes))

	for i, box in ipairs(newBoxes.boxes) do
		box = meshport.sort_box(box)
		box[5] = level / 64 - 0.5
		newBoxes.boxes[i] = box
	end

	return newBoxes
end

function meshport.Boxes:to_faces(nodeTiles, pos, facedir)
	local faces = meshport.Faces:new()

	for _, b in ipairs(self.boxes) do
		b = meshport.sort_box(b)

		local sideFaces = {
			{{x = b[4], y = b[5], z = b[3]}, {x = b[4], y = b[5], z = b[6]}, {x = b[1], y = b[5], z = b[6]}, {x = b[1], y = b[5], z = b[3]}}, -- Y+
			{{x = b[4], y = b[2], z = b[6]}, {x = b[4], y = b[2], z = b[3]}, {x = b[1], y = b[2], z = b[3]}, {x = b[1], y = b[2], z = b[6]}}, -- Y-
			{{x = b[4], y = b[2], z = b[6]}, {x = b[4], y = b[5], z = b[6]}, {x = b[4], y = b[5], z = b[3]}, {x = b[4], y = b[2], z = b[3]}}, -- X+
			{{x = b[1], y = b[2], z = b[3]}, {x = b[1], y = b[5], z = b[3]}, {x = b[1], y = b[5], z = b[6]}, {x = b[1], y = b[2], z = b[6]}}, -- X-
			{{x = b[1], y = b[2], z = b[6]}, {x = b[1], y = b[5], z = b[6]}, {x = b[4], y = b[5], z = b[6]}, {x = b[4], y = b[2], z = b[6]}}, -- Z+
			{{x = b[4], y = b[2], z = b[3]}, {x = b[4], y = b[5], z = b[3]}, {x = b[1], y = b[5], z = b[3]}, {x = b[1], y = b[2], z = b[3]}}, -- Z-
		}

		local sideTexCoords = {
			{{x = b[4], y = b[3]}, {x = b[4], y = b[6]}, {x = b[1], y = b[6]}, {x = b[1], y = b[3]}}, -- Y+
			{{x = b[4], y =-b[6]}, {x = b[4], y =-b[3]}, {x = b[1], y =-b[3]}, {x = b[1], y =-b[6]}}, -- Y-
			{{x = b[6], y = b[2]}, {x = b[6], y = b[5]}, {x = b[3], y = b[5]}, {x = b[3], y = b[2]}}, -- X+
			{{x =-b[3], y = b[2]}, {x =-b[3], y = b[5]}, {x =-b[6], y = b[5]}, {x =-b[6], y = b[2]}}, -- X-
			{{x =-b[1], y = b[2]}, {x =-b[1], y = b[5]}, {x =-b[4], y = b[5]}, {x =-b[4], y = b[2]}}, -- Z+
			{{x = b[4], y = b[2]}, {x = b[4], y = b[5]}, {x = b[1], y = b[5]}, {x = b[1], y = b[2]}}, -- Z-
		}

		local tileIdx, vertNorm

		for i = 1, 6 do
			-- Fix offset texture coordinates.
			for v = 1, 4 do
				sideTexCoords[i][v] = {x = sideTexCoords[i][v].x + 0.5, y = sideTexCoords[i][v].y + 0.5}
			end

			vertNorm = meshport.neighbor_dirs[i]

			faces:insert_face(meshport.prepare_cuboid_face({
				verts = sideFaces[i],
				tex_coords = sideTexCoords[i],
				vert_norms = {vertNorm, vertNorm, vertNorm, vertNorm},
			}, nodeTiles, pos, facedir, i))
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

		for i, name in ipairs(meshport.side_box_names) do
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
		prepNodebox.wall_top:transform(function(v) return {x = -v.x, y = -v.y, z = v.z} end)
		prepNodebox.wall_side:transform(function(v) return {x = -v.z, y = v.x, z = v.y} end)
	end

	return prepNodebox
end

function meshport.collect_boxes(prepNodebox, nodeDef, facedir, param2, neighbors)
	local boxes = meshport.Boxes:new()

	if prepNodebox.fixed then
		if prepNodebox.type == "leveled" then
			boxes:insert_all(prepNodebox.fixed:get_leveled(
					nodeDef.paramtype2 == "leveled" and param2 or nodeDef.leveled or 0))
		else
			boxes:insert_all(prepNodebox.fixed)
		end
	end

	if prepNodebox.type == "connected" then
		local neighborName

		for i = 1, 6 do
			neighborName = minetest.get_name_from_content_id(neighbors[i])

			if meshport.node_connects_to(neighborName, nodeDef.connects_to) then
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
