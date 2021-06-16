# Original script (interpolation): Techy5
# Expanded script: GreenXenith

### Use better materials and support alpha ###
# Usage: Open or copy script in Blender
# Run script while object is selected

import bpy

for mat in bpy.data.materials:
    try:
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links

        # Remove all nodes except texture
        for node in nodes:
            if node.type != "TEX_IMAGE":
                nodes.remove(node)

        # Change image interpolation
        tex = nodes["Image Texture"]
        tex.interpolation = "Closest"
        tex.location = 0, 0

        # Create texture coordinate node
        coord = nodes.new("ShaderNodeTexCoord")
        coord.location = -400, 0

        # Create mapping node
        map = nodes.new("ShaderNodeMapping")
        map.location = -200, 0

        # Create principled shader
        prin = nodes.new("ShaderNodeBsdfPrincipled")
        prin.location = 300, 0
        prin.inputs["Specular"].default_value = 0

        # Create output
        out = nodes.new("ShaderNodeOutputMaterial")
        out.location = 600, 0

        # Link everything
        links.new(coord.outputs[2], map.inputs[0]) # Coord > Map
        links.new(map.outputs[0], tex.inputs[0]) # Map > Texture
        links.new(tex.outputs[0], prin.inputs[0]) # Texture Color > Principled Color
        links.new(tex.outputs[1], prin.inputs[19]) # Texture Alpha > Principled Alpha
        links.new(prin.outputs[0], out.inputs[0]) # Principled > Output

        # Deselect all
        for node in nodes:
            node.select = False

        # Set blend mode
        mat.blend_method = "CLIP"

    except:
        continue
