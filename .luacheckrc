unused_args = false
allow_defined_top = true
max_line_length = 999

globals = {
    "meshport",
}

read_globals = {
    string = {fields = {"split", "trim"}},
    table = {fields = {"copy", "getn", "indexof"}},

    "minetest",
    "PseudoRandom",
    "vector",
    "VoxelArea",
}
