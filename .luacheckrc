std = "lua51"
max_line_length = false
allow_defined_top = true
global = false
unused_args = false
exclude_files = { "third_party/**" }

files["tests/**"] = { ignore = { "43[12]" } }
