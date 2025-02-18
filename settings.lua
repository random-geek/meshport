meshport.config = {}

-- taken from https://github.com/minetest-mods/areas/
local function setting(name, tp, default, config)
	local full_name = core.get_current_modname().."." .. name
	local value
	if tp == "bool" then
		value = core.settings:get_bool(full_name)
		default = value == nil and core.is_yes(default)
	elseif tp == "string" then
		value = core.settings:get(full_name)
	elseif tp == "v3f" then
		value = core.setting_get_pos(full_name)
		default = value == nil and core.string_to_pos(default)
	elseif tp == "float" or tp == "int" then
		value = tonumber(core.settings:get(full_name))
		local v, other = default:match("^(%S+) (.+)")
		default = value == nil and tonumber(other and v or default)
	else
		error("Cannot parse setting type " .. tp)
	end

	if value == nil then
		value = default
		assert(default ~= nil, "Cannot parse default for " .. full_name)
	end
	--print("add", name, default, value)
	config[name] = value
end

--------------
-- Settings --
--------------

setting("webhook_url", "string", "", meshport.config)
setting("embed_textures", "bool", false, meshport.config)
