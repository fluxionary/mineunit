local function noop(...) end
local function dummy_coords(...) return { x = 123, y = 123, z = 123 } end
local noop_object = {
	__call = function(self,...) return self end,
	__index = function(...) return function(...)end end,
}

_G.world = mineunit("world")

_G.core.is_singleplayer = function() return true end
_G.core.notify_authentication_modified = noop

_G.core.set_node = world.set_node
_G.core.add_node = world.set_node
_G.core.swap_node = world.swap_node

_G.core.get_worldpath = function(...) return _G.mineunit:get_worldpath(...) end
_G.core.get_modpath = function(...) return _G.mineunit:get_modpath(...) end
_G.core.get_current_modname = function(...) return _G.mineunit:get_current_modname(...) end
_G.core.register_item_raw = noop
_G.core.unregister_item_raw = noop
_G.core.register_alias_raw = noop
_G.minetest = _G.core

mineunit("settings")
_G.core.settings = _G.Settings(fixture_path("minetest.conf"))
mineunit:apply_default_settings(_G.core.settings)

_G.core.register_on_joinplayer = noop
_G.core.register_on_leaveplayer = noop

mineunit("game/constants")
mineunit("game/item")
mineunit("game/misc")
mineunit("game/register")
mineunit("game/privileges")
mineunit("game/features")
mineunit("common/misc_helpers")
mineunit("common/vector")
mineunit("common/serialize")
mineunit("common/fs")

assert(minetest.registered_nodes["air"])
assert(minetest.registered_nodes["ignore"])
assert(minetest.registered_items[""])
assert(minetest.registered_items["unknown"])

mineunit("metadata")
mineunit("itemstack")

local mod_storage
_G.minetest.get_mod_storage = function()
	if not mod_storage then
		mod_storage = MetaDataRef()
	end
	return mod_storage
end

_G.minetest.sound_play = noop
_G.minetest.sound_stop = noop
_G.minetest.sound_fade = noop
_G.minetest.add_particlespawner = noop

_G.minetest.registered_chatcommands = {}
_G.minetest.register_chatcommand = noop
_G.minetest.chat_send_player = function(...) print(unpack({...})) end
_G.minetest.register_on_player_receive_fields = noop
_G.minetest.register_on_placenode = noop
_G.minetest.register_on_dignode = noop
_G.minetest.register_on_mods_loaded = function(func) mineunit:register_on_mods_loaded(func) end

_G.minetest.item_drop = noop
_G.minetest.add_item = noop
_G.minetest.check_for_falling = noop
_G.minetest.get_objects_inside_radius = function(...) return {} end

_G.minetest.register_biome = noop
_G.minetest.clear_registered_biomes = function(...) error("MINEUNIT UNSUPPORTED CORE METHOD") end
_G.minetest.register_ore = noop
_G.minetest.clear_registered_ores = function(...) error("MINEUNIT UNSUPPORTED CORE METHOD") end
_G.minetest.register_decoration = noop
_G.minetest.clear_registered_decorations = function(...) error("MINEUNIT UNSUPPORTED CORE METHOD") end

do
	local time_step = tonumber(mineunit:config("time_step"))
	assert(time_step, "Invalid configuration value for time_step. Number expected.")
	if time_step < 0 then
		mineunit:info("Running default core.get_us_time using real world wall clock.")
		_G.minetest.get_us_time = function()
			local socket = require 'socket'
			-- FIXME: Returns the time in seconds, relative to the origin of the universe.
			return socket.gettime() * 1000 * 1000
		end
	else
		mineunit:info("Running custom core.get_us_time with step increment: "..tostring(time_step))
		local time_now = 0
		_G.minetest.get_us_time = function()
			time_now = time_now + time_step
			return time_now
		end
	end
end

_G.minetest.after = noop

_G.minetest.find_nodes_with_meta = _G.world.find_nodes_with_meta
_G.minetest.find_nodes_in_area = _G.world.find_nodes_in_area
_G.minetest.get_node_or_nil = _G.world.get_node
_G.minetest.get_node = function(pos) return minetest.get_node_or_nil(pos) or {name="ignore",param2=0} end
_G.minetest.dig_node = function(pos) return world.on_dig(pos) and true or false end
_G.minetest.remove_node = _G.world.remove_node

_G.minetest.get_node_timer = {}
setmetatable(_G.minetest.get_node_timer, noop_object)

local content_name2id = {}
local content_id2name = {}
_G.minetest.get_content_id = function(name)
	-- check if the node exists
	assert(minetest.registered_nodes[name], "node " .. name .. " is not registered")

	-- create and increment
	if not content_name2id[name] then
		content_name2id[name] = #content_id2name
		table.insert(content_id2name, name)
	end
	return content_name2id[name]
end

_G.minetest.get_name_from_content_id = function(cid)
	assert(content_id2name[cid+1], "Unknown content id")
	return content_id2name[cid+1]
end

--
-- Minetest default noop table
-- FIXME: default should not be here, it should be separate file and not loaded with core
--
_G.default = {
	LIGHT_MAX = 14,
	get_translator = string.format,
}
setmetatable(_G.default, noop_object)
