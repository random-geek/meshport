# Original script: random-geek
# Contributors: GreenXenith, sbrl, VorTechnix

### Use better materials and support alpha ###
# Usage: Open or copy script in Blender
# Run script WHILE OBJECT IS SELECTED

import bpy

targetMats = []

for obj in bpy.context.selected_objects:
    for slot in obj.material_slots:
        mat = slot.material

        if mat not in targetMats:
            targetMats.append(mat)

for mat in targetMats:
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    # Remove all nodes except texture
    for node in nodes:
        if node.bl_idname != "ShaderNodeTexImage":
            nodes.remove(node)

    # Get texture node
    try:
        tex = nodes["Image Texture"]
    except KeyError:
        print(f"[materials.py] Skipped material '{mat.name}': Image texture not found.")
        continue

    # Change image interpolation
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
    if int(bpy.app.version_string.split('.')[0]) >= 4:
        prin.inputs["Specular IOR Level"].default_value = 0
    else:
        prin.inputs["Specular"].default_value = 0

    # Create output
    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = 600, 0

    # Link everything
    links.new(coord.outputs["UV"], map.inputs["Vector"])
    links.new(map.outputs["Vector"], tex.inputs["Vector"])
    links.new(tex.outputs["Color"], prin.inputs["Base Color"])
    links.new(tex.outputs["Alpha"], prin.inputs["Alpha"])
    links.new(prin.outputs["BSDF"], out.inputs["Surface"])

    # Deselect all
    for node in nodes:
        node.select = False

    # Set blend mode
    mat.blend_method = "CLIP"
