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
        coord.location = -600, 0

        # Create mapping node
        map = nodes.new("ShaderNodeMapping")
        map.location = -400, 0

        # Create principled shader
        prin = nodes.new("ShaderNodeBsdfPrincipled")
        prin.location = 200, 0
        prin.inputs["Specular"].default_value = 0

        # Create transparent shader
        trans = nodes.new("ShaderNodeBsdfTransparent")
        trans.location = 400, -150

        # Create mix shader
        mix = nodes.new("ShaderNodeMixShader")
        mix.location = 600, 0

        # Create output
        out = nodes.new("ShaderNodeOutputMaterial")
        out.location = 800, 0

        # Link everything
        links.new(coord.outputs[2], map.inputs[0]) # Coord > Map
        links.new(map.outputs[0], tex.inputs[0]) # Map > Texture
        links.new(tex.outputs[0], prin.inputs[0]) # Texture > Principled
        links.new(prin.outputs[0], mix.inputs[2]) # Principled > Mix

        links.new(trans.outputs[0], mix.inputs[1]) # Transparent > Mix
        links.new(tex.outputs[1], mix.inputs[0]) # Texture alpha > Mix factor

        links.new(mix.outputs[0], out.inputs[0]) # Mix > Output

        # Deselect all
        for node in nodes:
            node.select = False

    except:
        continue
