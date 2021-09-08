-- FIXME: Sorry, not exactly nice in its current state
-- Have extra time and energy? Feel free to clean it a bit

local pl = {
	path = require 'pl.path',
	--dir = require 'pl.dir',
}

local lua_dofile = dofile
function _G.dofile(path, ...)
	return lua_dofile(pl.path.normpath(path), ...)
end

local default_config = {
	verbose = 2,
	print = true,
	modname = "mineunit",
	root = ".",
	mineunit_path = debug.getinfo(1).source:match("@?(.*)/"),
	spec_path = "spec",
	fixture_paths = {
		"spec/fixtures"
	},
	source_path = ".",
}

mineunit = {
	_config = {
		modpaths = {},
	},
	_on_mods_loaded = {},
	_on_mods_loaded_exec_count = 0,
}

require("mineunit.globals")

local function mineunit_path(name)
	return pl.path.normpath(string.format("%s/%s", mineunit:config("mineunit_path"), name))
end

mineunit.__index = mineunit
local _mineunits = {}
setmetatable(mineunit, {
	__call = function(self, name)
		local res
		if not _mineunits[name] then
			mineunit:debug("Loading mineunit module", name)
			res = require("mineunit." .. name:gsub("/", "."))
		end
		_mineunits[name] = true
		return res
	end,
})

if mineunit_config then
	for key in pairs(default_config) do
		if mineunit_config[key] ~= nil then
			mineunit._config[key] = mineunit_config[key]
		end
	end
end

function mineunit:config(key)
	if self._config[key] ~= nil then
		return self._config[key]
	end
	return default_config[key]
end
mineunit._config.source_path = pl.path.normpath(("%s/%s"):format(mineunit:config("root"), mineunit:config("source_path")))

local luaprint = _G.print
function mineunit:debug(...)   if self:config("verbose") > 3 then luaprint("D:",...) end end
function mineunit:info(...)    if self:config("verbose") > 2 then luaprint("I:",...) end end
function mineunit:warning(...) if self:config("verbose") > 1 then luaprint("W:",...) end end
function mineunit:error(...)   if self:config("verbose") > 0 then luaprint("E:",...) end end
function mineunit:print(...)   if self:config("print")       then luaprint(...) end end
_G.print = function(...) mineunit:print(...) end

function mineunit:set_modpath(name, path)
	mineunit:info("Setting modpath", name, path)
	self._config.modpaths[name] = path
end

function mineunit:get_modpath(name)
	return self._config.modpaths[name]
end

function mineunit:get_current_modname()
	return self:config("modname")
end

function mineunit:set_current_modname(name)
	self._config.modname = name
end

function mineunit:restore_current_modname()
	self._config.modname = self:config("original_modname")
end

function mineunit:get_worldpath()
	return self:config("fixture_paths")[1]
end

function mineunit:register_on_mods_loaded(func)
	if self._on_mods_loaded_exec_count > 0 then
		mineunit:warning("mineunit:register_on_mods_loaded: Registering after register_on_mods_loaded executed")
	end
	if type(func) == "function" then
		table.insert(self._on_mods_loaded, func)
	end
end

function mineunit:mods_loaded()
	if self._on_mods_loaded then
		mineunit:info("Executing register_on_mods_loaded functions")
		if self._on_mods_loaded_exec_count > 0 then
			mineunit:warning("mineunit:mods_loaded: Callbacks already executed " .. self._on_mods_loaded_exec_count .. " times")
		end
		for _,func in ipairs(self._on_mods_loaded) do func() end
		self._on_mods_loaded_exec_count = self._on_mods_loaded_exec_count + 1
	end
end

local function spec_path(name)
	local path = pl.path.normpath(("%s/%s/%s"):format(mineunit:config("root"), mineunit:config("spec_path"), name))
	if pl.path.isfile(path) then
		mineunit:debug("spec_path", path)
		return path
	end
	mineunit:debug("spec_path, file not found:", path)
end

function fixture_path(name)
	local index = name:find(mineunit:get_worldpath(), nil, true)
	if index then
		-- Remove worldpath from name, worldpath should be in search_paths.
		-- This is to allow using search_paths when mod creates Settings object from worldpath.
		name = name:sub(1, index - 1) .. name:sub(index + #mineunit:get_worldpath())
	end
	local root = mineunit:config("root")
	local search_paths = mineunit:config("fixture_paths")
	for _,search_path in ipairs(search_paths) do
		local path = pl.path.normpath(("%s/%s/%s"):format(root, search_path, name))
		if pl.path.isfile(path) then
			return path
		else
			mineunit:debug("fixture_path, file not found:", path)
		end
	end
	local path = pl.path.normpath(("%s/%s/%s"):format(root, search_paths[1], name))
	mineunit:info("File not found:", path)
	return path
end

local _fixtures = {}
function fixture(name)
	local path = fixture_path(name .. ".lua")
	if not _fixtures[name] then
		mineunit:info("Loading fixture", path)
		assert(pl.path.isfile(path), "Fixture not found: " .. path)
		dofile(path)
	else
		mineunit:debug("Fixture already loaded", path)
	end
	_fixtures[name] = true
end

local function source_path(name)
	local source_path = mineunit:config("source_path")
	local path = pl.path.normpath(("%s/%s"):format(source_path, name))
	mineunit:debug("source_path", path)
	return path
end

function sourcefile(name)
	local path = source_path(name .. ".lua")
	mineunit:info("Loading source", path)
	assert(pl.path.isfile(path), "Source file not found: " .. path)
	return dofile(path)
end

function DEPRECATED(msg)
	-- TODO: Add configurable behavior to fail or warn when deprectaed things are used
	-- Now it has to be fail. Warnings are for pussies, hard fail for serious Sam.
	error(msg or "Attempted to use deprecated method")
end

function mineunit.export_object(obj, def)
	if _G[def.name] == nil or def.private then
		obj.__index = obj
		setmetatable(obj, {
			__call = function(...)
				local obj = def.constructor(...)
				obj._mineunit_typename = def.typename or def.name
				return obj
			end
		})
		if not def.private then
			_G[def.name] = obj
		end
	else
		error("Error: mineunit.export_object object name is already reserved:" .. (def.name or "?"))
	end
end

mineunit.utils = mineunit("assert")
local sequential = mineunit.utils.sequential
-- FIXME: Required for some existing tests
count = mineunit.utils.count

function mineunit.deep_merge(data, target, defaults)
	if sequential(data) and #data > 0 then
		assert(sequential(defaults), "Configuration: attempt to merge indexed table with hash table")
		-- Indexed arrays merge strategy: discard keys, add unique values
		local seen = {}
		for _,value in ipairs(defaults) do
			table.insert(target, value)
			seen[value] = true
		end
		for _,value in ipairs(data) do
			assert(type(value) ~= "table", "Configuration: tables not supported in indexed arrays")
			if not seen[value] then
				table.insert(target, value)
				mineunit:debug("\t", #target, " = ", tostring(value))
			else
				mineunit:debug("\tSkipping duplicate value: ", tostring(value))
			end
		end
	else
		-- Hash tables merge strategy: preserve keys, override values
		for key,value in pairs(data) do
			if defaults[key] then
				assert(type(value) == type(defaults[key]), "Configuration: invalid data type for key", key)
				if type(value) == "table" then
					target[key] = {}
					mineunit:debug("Configuration: merging indexed array", key)
					mineunit.deep_merge(value, target[key], defaults[key])
				else
					target[key] = value
				end
				mineunit:debug("Configuration: ", key, tostring(value))
			elseif key ~= "exclude" then
				-- Excluding "exclude" is hack and on todo list, mineunit cli runner uses this configuration key
				mineunit:warning("Configuration: invalid key", key)
			end
		end
	end
end

do -- Read mineunit config file
	local configpath = spec_path("mineunit.conf")
	if not configpath then
		mineunit:info("configpath, file not found:", configpath)
	end
	if configpath then
		local configfile, err = loadfile(configpath)
		if configfile then
			local configenv = {}
			setfenv(configfile, configenv)
			configfile()
			mineunit.deep_merge(configenv, mineunit._config, default_config)
			-- Override config
			if mineunit_conf_override then
				for k, v in pairs(mineunit_conf_override) do
					mineunit._config[k] = v
				end
			end
			mineunit:info("Mineunit configuration loaded from", configpath)
		else
			mineunit:warning("Mineunit configuration failed: " .. err)
		end
	else
		mineunit:warning("Mineunit configuration file not found")
	end
end

do -- Read mod.conf config file
	local modconfpath = source_path("mod.conf")
	if not modconfpath then
		mineunit:info("mod.conf not found:", modconfpath)
		return
	end
	local configfile = io.open(modconfpath, "r")
	if configfile then
		for line in configfile:lines() do
			local key, value = string.gmatch(line, "([^=%s]+)%s*=%s*(.-)%s*$")()
			if key == "name" then
				if mineunit._config["modname"] then
					mineunit:warning("Mod name defined in both mod.conf and mineunit.conf, using mineunit.conf")
				else
					mineunit._config["modname"] = value
				end
			end
		end
		mineunit:info("Mod configuration loaded from", modconfpath)
	else
		mineunit:warning("Loading file mod.conf failed")
	end
end

-- Save original modname and set modpath
mineunit._config["original_modname"] = mineunit:config("modname")
mineunit:set_modpath(mineunit:config("modname"), mineunit:config("root"))

function timeit(count, func, ...)
	local socket = require 'socket'
	local t1 = socket.gettime() * 1000
	for i=0,count do
		func(...)
	end
	local diff = (socket.gettime() * 1000) - t1
	local info = debug.getinfo(func,'S')
	mineunit:info(("\nTimeit: %s:%d took %d ticks"):format(info.short_src, info.linedefined, diff))
	return diff, info
end

mineunit:info("Mineunit initialized, current modname is", mineunit:get_current_modname())
