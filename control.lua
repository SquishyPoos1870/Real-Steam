local TARGET_TYPES = {
  ["generator"] = true,
  ["boiler"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true
}

local TARGET_NAMES = {
  ["steam-engine"] = true,
  ["steam-turbine"] = true,
  ["boiler"] = true,
  ["heat-exchanger"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true
}

local SMOKE_BY_NAME = {
  ["steam-engine"] = "real-steam-soft-vapour",
  ["steam-turbine"] = "real-steam-turbine-mist",
  ["boiler"] = "real-steam-pressure-puff",
  ["heat-exchanger"] = "real-steam-cold-vapour",
  ["pipe"] = "real-steam-pipe-whisper",
  ["pipe-to-ground"] = "real-steam-pipe-whisper"
}

local PIPE_DRIBBLE_SMOKE_NAME = "real-steam-pipe-dribble"
local PIPE_FULL_LEAK_SMOKE_NAME = "real-steam-pipe-full-leak"
local PIPE_WIND_SMOKE_NAME = "real-steam-pipe-whisper-wind"
local PIPE_FULL_WIND_SMOKE_NAME = "real-steam-pipe-full-leak-wind"
local PIPE_DRIBBLE_WIND_SMOKE_NAME = "real-steam-pipe-dribble-wind"

local LOCAL_VENT_OFFSET_BY_NAME = {
  -- Local vent positions for a north-facing entity. Rotated by entity.direction.
  ["steam-engine"] = {0.00, -0.95},
  ["steam-turbine"] = {0.00, -1.10},
  ["boiler"] = {0.45, -0.72},
  ["heat-exchanger"] = {0.35, -0.88},
  ["pipe"] = {0.00, 0.00},
  ["pipe-to-ground"] = {0.00, -0.15}
}

local function ensure_storage()
  storage.real_steam_entities = storage.real_steam_entities or {}
  storage.real_steam_keys = storage.real_steam_keys or {}
  storage.real_steam_key_set = storage.real_steam_key_set or {}
  storage.real_steam_cursor = storage.real_steam_cursor or 1
end

local function rotate_offset(offset, direction)
  local x, y = offset[1], offset[2]
  direction = direction or defines.direction.north

  if direction == defines.direction.north then
    return {x, y}
  elseif direction == defines.direction.east then
    return {-y, x}
  elseif direction == defines.direction.south then
    return {-x, -y}
  elseif direction == defines.direction.west then
    return {y, -x}
  elseif direction == defines.direction.northeast then
    return {(x - y) * 0.70710678, (x + y) * 0.70710678}
  elseif direction == defines.direction.southeast then
    return {(-x - y) * 0.70710678, (x - y) * 0.70710678}
  elseif direction == defines.direction.southwest then
    return {(-x + y) * 0.70710678, (-x - y) * 0.70710678}
  elseif direction == defines.direction.northwest then
    return {(x + y) * 0.70710678, (-x + y) * 0.70710678}
  end

  return {x, y}
end

local function get_vent_offset(entity)
  local local_offset = LOCAL_VENT_OFFSET_BY_NAME[entity.name] or {0, -0.75}
  return rotate_offset(local_offset, entity.direction)
end

local function is_target(entity)
  return entity and entity.valid and TARGET_TYPES[entity.type] and TARGET_NAMES[entity.name]
end

local function entity_key(entity)
  if entity.unit_number then
    return entity.unit_number
  end

  -- Some simple entities may not expose a unit_number. Track them by stable surface/name/position.
  local pos = entity.position
  return table.concat({entity.surface.index, entity.name, math.floor(pos.x * 100), math.floor(pos.y * 100)}, ":")
end

local function entity_numeric_index(entity, key)
  if entity.unit_number then
    return entity.unit_number
  end

  if type(key) == "number" then
    return key
  end

  local pos = entity.position
  return math.abs(math.floor((pos.x * 31) + (pos.y * 17) + (entity.surface.index * 101)))
end

local function leak_roll(tick, numeric_index, salt)
  -- Deterministic pseudo-random roll for multiplayer-safe tiny leak variation.
  -- Avoid math.random so the visual effect stays safe in multiplayer/saves.
  local phase = math.floor(tick / 17)
  local mixed = (phase * 1103) + (numeric_index * 9176) + (salt * 7919)
  mixed = mixed + math.floor(mixed / 7) + (mixed % 37) * 13
  return math.abs(mixed) % 100
end

local function leak_float(tick, numeric_index, salt, radius)
  return ((leak_roll(tick, numeric_index, salt) - 50) / 50) * radius
end

local function pipe_steam_amount(entity)
  if not entity or not entity.valid or not entity.fluidbox or #entity.fluidbox == 0 then
    return 0
  end

  local amount = 0
  for i = 1, #entity.fluidbox do
    local fluid = entity.fluidbox[i]
    if fluid and fluid.name == "steam" then
      amount = amount + (fluid.amount or 0)
    end
  end

  return amount
end

local function pipe_leak_chance(entity, steam_amount)
  local density = settings.global["real-steam-density"].value
  local base = 5
  if density == "high" then
    base = 20
  elseif density == "balanced" then
    base = 11
  end

  local fullness_bonus = 0
  if steam_amount >= 80 then
    fullness_bonus = 22
  elseif steam_amount >= 45 then
    fullness_bonus = 15
  elseif steam_amount >= 15 then
    fullness_bonus = 9
  elseif steam_amount >= 1 then
    fullness_bonus = 4
  end

  -- Underground joins look like natural pressure/leak points, so they should still read clearly.
  local join_bonus = entity.name == "pipe-to-ground" and 16 or 0
  local chance = base + fullness_bonus + join_bonus
  if chance > 62 then return 62 end
  return chance
end

local function pipe_leak_candidate_limit(entity, steam_amount)
  local density = settings.global["real-steam-density"].value
  local limit = 5
  if density == "high" then
    limit = 16
  elseif density == "balanced" then
    limit = 9
  end

  if steam_amount >= 80 then
    limit = limit + 8
  elseif steam_amount >= 45 then
    limit = limit + 5
  elseif steam_amount >= 15 then
    limit = limit + 2
  end

  -- Pipe-to-ground sections are the main visible leak points. Straight pipes are quieter.
  if entity.name == "pipe-to-ground" then
    limit = limit + 42
  end

  if limit > 78 then return 78 end
  return limit
end

local function pipe_is_leak_candidate(entity, numeric_index, tick, steam_amount)
  -- A slow gate stops every straight pipe segment in a line from smoking at once.
  -- The active leak candidates reshuffle occasionally so different places can look worn over time.
  local slow_tick = math.floor(tick / 900) * 900
  return leak_roll(slow_tick, numeric_index, 1277) < pipe_leak_candidate_limit(entity, steam_amount)
end

local function pipe_fullness_tier(steam_amount)
  if steam_amount >= 80 then return 3 end
  if steam_amount >= 45 then return 2 end
  if steam_amount >= 15 then return 1 end
  return 0
end

local function register_entity(entity)
  if not is_target(entity) then return end
  if entity.name == "boiler" and not settings.global["real-steam-include-boilers"].value then return end
  if (entity.name == "pipe" or entity.name == "pipe-to-ground") and not settings.global["real-steam-include-pipes"].value then return end

  ensure_storage()
  local key = entity_key(entity)
  storage.real_steam_entities[key] = entity

  if not storage.real_steam_key_set[key] then
    storage.real_steam_key_set[key] = true
    table.insert(storage.real_steam_keys, key)
  end
end

local function unregister_entity(entity)
  if not entity then return end

  ensure_storage()
  local key = entity_key(entity)
  storage.real_steam_entities[key] = nil
  storage.real_steam_key_set[key] = nil
end

local function compact_entity_keys()
  ensure_storage()

  local compacted = {}
  local key_set = {}

  for _, key in ipairs(storage.real_steam_keys) do
    if storage.real_steam_entities[key] then
      table.insert(compacted, key)
      key_set[key] = true
    end
  end

  storage.real_steam_keys = compacted
  storage.real_steam_key_set = key_set

  if #storage.real_steam_keys == 0 then
    storage.real_steam_cursor = 1
  elseif storage.real_steam_cursor > #storage.real_steam_keys then
    storage.real_steam_cursor = 1
  end
end

local function scan_surface(surface)
  if not surface or not surface.valid then return end

  for _, entity in pairs(surface.find_entities_filtered{type = "generator"}) do
    register_entity(entity)
  end

  for _, entity in pairs(surface.find_entities_filtered{type = "boiler"}) do
    register_entity(entity)
  end

  if settings.global["real-steam-include-pipes"].value then
    for _, entity in pairs(surface.find_entities_filtered{type = "pipe"}) do
      register_entity(entity)
    end
    for _, entity in pairs(surface.find_entities_filtered{type = "pipe-to-ground"}) do
      register_entity(entity)
    end
  end
end

local function rescan_all()
  storage.real_steam_entities = {}
  storage.real_steam_keys = {}
  storage.real_steam_key_set = {}
  storage.real_steam_cursor = 1

  for _, surface in pairs(game.surfaces) do
    scan_surface(surface)
  end
end

local function entity_is_working(entity)
  if not entity or not entity.valid then return false end

  if entity.status == defines.entity_status.working then
    return true
  end

  if entity.status == defines.entity_status.no_power or
     entity.status == defines.entity_status.no_fuel or
     entity.status == defines.entity_status.disabled_by_control_behavior or
     entity.status == defines.entity_status.marked_for_deconstruction then
    return false
  end

  return entity.active == true
end

local function entity_has_steam(entity)
  if not entity or not entity.valid or not entity.fluidbox or #entity.fluidbox == 0 then
    return false
  end

  for i = 1, #entity.fluidbox do
    local fluid = entity.fluidbox[i]
    if fluid and fluid.name == "steam" and (fluid.amount or 0) > 0.2 then
      return true
    end
  end

  return false
end

local function safe_read(entity, property_name)
  local ok, value = pcall(function()
    return entity[property_name]
  end)

  if ok then
    return value
  end

  return nil
end

local function clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function setting_enabled(name)
  local entry = settings.global[name]
  return entry and entry.value == true
end

local QUALITY_LEAK_SCALE = {
  normal = 1.00,
  uncommon = 0.75,
  rare = 0.50,
  epic = 0.28,
  legendary = 0.12
}

local function entity_quality_name(entity)
  local quality = safe_read(entity, "quality")
  if not quality then
    return "normal"
  end

  if type(quality) == "string" then
    return quality
  end

  local ok, name = pcall(function()
    return quality.name
  end)

  if ok and type(name) == "string" then
    return name
  end

  return "normal"
end

local function quality_leak_scale(entity)
  if not setting_enabled("real-steam-quality-reduces-leaks") then
    return 1.00
  end

  local quality_name = entity_quality_name(entity)
  return QUALITY_LEAK_SCALE[quality_name] or 1.00
end

local function passes_quality_visual_gate(tick, numeric_index, scale, salt)
  if scale >= 0.995 then
    return true
  end

  local threshold = math.floor(100 * clamp(scale, 0.02, 1.00))
  return leak_roll(tick, numeric_index, salt) < threshold
end

local function real_rain_weather(surface)
  if not setting_enabled("real-steam-weather-integration") then return nil end
  if not (surface and surface.valid) then return nil end
  if not (remote and remote.interfaces and remote.interfaces["real-rain"]) then return nil end
  if not remote.interfaces["real-rain"]["get_weather"] then return nil end

  local ok, weather = pcall(remote.call, "real-rain", "get_weather", surface.index)
  if ok and type(weather) == "table" then return weather end
  return nil
end

local function real_wind_data(surface)
  if not setting_enabled("real-steam-weather-integration") then return nil end
  if not (surface and surface.valid) then return nil end
  if not (remote and remote.interfaces and remote.interfaces["real-wind"]) then return nil end
  if not remote.interfaces["real-wind"]["get_wind"] then return nil end

  local ok, wind = pcall(remote.call, "real-wind", "get_wind", surface.index)
  if ok and type(wind) == "table" then return wind end
  return nil
end

local EMPTY_WEATHER_CONTEXT = { active = false, raining = false, storm = 1, wind_bonus = 0, gust = false }
local WEATHER_CONTEXT_CACHE_TICK = nil
local WEATHER_CONTEXT_CACHE = {}

local function build_weather_context(surface)
  local rain = real_rain_weather(surface)
  local wind = real_wind_data(surface)
  if not rain and not wind then
    return EMPTY_WEATHER_CONTEXT
  end

  local storm = clamp(tonumber(rain and rain.storm_factor) or tonumber(wind and wind.storm_factor) or 1, 0.5, 3.0)
  local speed = tonumber(rain and rain.wind_speed) or tonumber(wind and wind.speed) or 0
  local bucket = (rain and rain.wind_bucket) or (wind and wind.wind_bucket)
  local wind_bonus = clamp(speed / 0.075, 0, 1.6)
  local raining = rain and rain.is_raining == true

  return {
    active = raining or wind_bonus > 0.08 or bucket == "gust",
    raining = raining,
    storm = storm,
    wind_bonus = wind_bonus,
    gust = bucket == "gust" or wind_bonus > 1.0
  }
end

local function weather_context(surface, tick)
  if not (surface and surface.valid) then
    return EMPTY_WEATHER_CONTEXT
  end

  tick = tick or game.tick
  if WEATHER_CONTEXT_CACHE_TICK ~= tick then
    WEATHER_CONTEXT_CACHE_TICK = tick
    WEATHER_CONTEXT_CACHE = {}
  end

  local surface_index = surface.index
  local cached = WEATHER_CONTEXT_CACHE[surface_index]
  if cached then
    return cached
  end

  local context = build_weather_context(surface)
  WEATHER_CONTEXT_CACHE[surface_index] = context
  return context
end

local function steam_generator_is_actually_generating(entity)
  if not entity_has_steam(entity) then
    return false
  end

  if entity.status ~= defines.entity_status.working then
    return false
  end

  -- Steam engines/turbines can still contain steam when disconnected or idle.
  -- electric_output_flow is the strongest signal that the generator is producing useful power.
  local output_flow = safe_read(entity, "electric_output_flow")
  if type(output_flow) == "number" then
    return output_flow > 0.001
  end

  -- Fallback for compatibility if the property is unavailable on a modded generator.
  return entity.active == true
end

local function steam_entity_should_emit(entity)
  if entity.name == "steam-engine" or entity.name == "steam-turbine" then
    return steam_generator_is_actually_generating(entity)
  end

  if entity.name == "boiler" or entity.name == "heat-exchanger" then
    return entity.status == defines.entity_status.working
  end

  return entity_is_working(entity)
end

local function density_interval()
  local density = settings.global["real-steam-density"].value
  if density == "low" then return 54 end
  if density == "high" then return 18 end
  return 36
end

local function update_budget()
  local density = settings.global["real-steam-density"].value
  if density == "high" then return 160 end
  if density == "balanced" then return 120 end
  return 80
end

local PIPE_EDGE_LEAK_POINTS = {
  {0.22, 0.00},
  {-0.22, 0.00},
  {0.00, 0.22},
  {0.00, -0.22},
  {0.16, 0.16},
  {-0.16, -0.16}
}

local function pipe_leak_offset(entity, numeric_index, tick)
  -- Pick a small edge/coupler position and hold that general area for a while.
  -- This looks cleaner than moving the leak all over the pipe body every puff.
  if entity.name == "pipe-to-ground" then
    local base = rotate_offset({0.00, -0.23}, entity.direction)
    local slow_tick = math.floor(tick / 720) * 720
    local side = leak_roll(slow_tick, numeric_index, 307) < 50 and -1 or 1
    local side_offset = rotate_offset({0.10 * side, 0.00}, entity.direction)
    local dx = base[1] + side_offset[1] + leak_float(tick, numeric_index, 409, 0.030)
    local dy = base[2] + side_offset[2] + leak_float(tick, numeric_index, 503, 0.030)
    return dx, dy
  end

  local slow_tick = math.floor(tick / 720) * 720
  local slot = (leak_roll(slow_tick, numeric_index, 101) % #PIPE_EDGE_LEAK_POINTS) + 1
  local point = PIPE_EDGE_LEAK_POINTS[slot]
  local dx = point[1] + leak_float(tick, numeric_index, 211, 0.026)
  local dy = point[2] + leak_float(tick, numeric_index, 313, 0.026)
  return dx, dy
end

local function spawn_steam(entity, tick, key)
  if entity.name == "boiler" and not settings.global["real-steam-include-boilers"].value then
    return
  end

  local is_pipe = (entity.name == "pipe" or entity.name == "pipe-to-ground")
  local numeric_index = entity_numeric_index(entity, key)
  local pipe_steam = 0
  local context = weather_context(entity.surface, tick)
  local quality_scale = quality_leak_scale(entity)

  if is_pipe then
    if not settings.global["real-steam-include-pipes"].value then
      return
    end
    pipe_steam = pipe_steam_amount(entity)
    if pipe_steam <= 0.2 then
      return
    end

    -- Clean leak pass: only selected pipe sections are allowed to leak, then fullness controls frequency.
    if not pipe_is_leak_candidate(entity, numeric_index, tick, pipe_steam) then
      return
    end

    if not passes_quality_visual_gate(tick, numeric_index, quality_scale, 1447) then
      return
    end

    local leak_chance = pipe_leak_chance(entity, pipe_steam)
    if context.raining then
      leak_chance = math.floor(leak_chance * clamp(0.96 - context.storm * 0.04, 0.78, 1.0))
    end
    if context.gust then
      leak_chance = math.min(76, leak_chance + math.floor(4 + context.wind_bonus * 3))
    end

    leak_chance = math.max(1, math.floor(leak_chance * quality_scale))

    if leak_roll(tick, numeric_index, 503) >= leak_chance then
      return
    end
  else
    if not steam_entity_should_emit(entity) then
      return
    end

    if not passes_quality_visual_gate(tick, numeric_index, quality_scale, 1601) then
      return
    end
  end

  local smoke_name = SMOKE_BY_NAME[entity.name] or "real-steam-soft-vapour"
  local pipe_tier = 0
  if is_pipe then
    pipe_tier = pipe_fullness_tier(pipe_steam)
    if pipe_tier >= 2 or entity.name == "pipe-to-ground" then
      smoke_name = PIPE_FULL_LEAK_SMOKE_NAME
    end

    if context.active and (context.wind_bonus > 0.10 or context.gust) then
      if smoke_name == PIPE_FULL_LEAK_SMOKE_NAME then
        smoke_name = PIPE_FULL_WIND_SMOKE_NAME
      else
        smoke_name = PIPE_WIND_SMOKE_NAME
      end
    end
  end

  local offset = get_vent_offset(entity)
  if is_pipe then
    local px, py = pipe_leak_offset(entity, numeric_index, tick)
    offset = {px, py}
  end

  local jitter_div_x = is_pipe and 2600 or 900
  local jitter_div_y = is_pipe and 2660 or 940
  local jitter_x = (((tick + numeric_index * 37) % 100) - 50) / jitter_div_x
  local jitter_y = (((tick + numeric_index * 53) % 100) - 50) / jitter_div_y
  local wind_jitter = 1 + context.wind_bonus * (is_pipe and 1.35 or 0.65) + (context.gust and 0.45 or 0) + (context.raining and context.storm * 0.08 or 0)
  jitter_x = jitter_x * wind_jitter
  jitter_y = jitter_y * wind_jitter

  local spawn_x = entity.position.x + offset[1] + jitter_x
  local spawn_y = entity.position.y + offset[2] + jitter_y

  entity.surface.create_trivial_smoke{
    name = smoke_name,
    position = {spawn_x, spawn_y}
  }

  if is_pipe then
    local roll = leak_roll(tick, numeric_index, 5)
    local extra_wisp_chance = 7 + (pipe_tier * 5)
    if entity.name == "pipe-to-ground" then
      extra_wisp_chance = extra_wisp_chance + 6
    end
    extra_wisp_chance = math.floor(extra_wisp_chance * quality_scale)

    if roll < extra_wisp_chance then
      -- Occasional second micro-wisp close to the leak point. No big pressure puff here.
      local drip_dx = leak_float(tick, numeric_index, 607, 0.032 + (pipe_tier * 0.006))
      local drip_dy = 0.018 + (leak_roll(tick, numeric_index, 709) / 3200)
      entity.surface.create_trivial_smoke{
        name = context.active and PIPE_DRIBBLE_WIND_SMOKE_NAME or PIPE_DRIBBLE_SMOKE_NAME,
        position = {spawn_x + drip_dx, spawn_y + drip_dy}
      }
    end
  end
end

local function process_tracked_entities(tick)
  ensure_storage()

  local keys = storage.real_steam_keys
  local total = #keys
  if total == 0 then return end

  local cursor = storage.real_steam_cursor or 1
  if cursor > total then cursor = 1 end

  local budget = update_budget()
  local processed = 0
  local visited = 0
  local had_stale_entries = false

  while processed < budget and visited < total do
    local key = keys[cursor]
    local entity = storage.real_steam_entities[key]

    if entity and entity.valid then
      spawn_steam(entity, tick, key)
      processed = processed + 1
    else
      storage.real_steam_entities[key] = nil
      storage.real_steam_key_set[key] = nil
      had_stale_entries = true
    end

    cursor = cursor + 1
    if cursor > total then cursor = 1 end
    visited = visited + 1
  end

  storage.real_steam_cursor = cursor

  if had_stale_entries and (tick % 1800 == 0) then
    compact_entity_keys()
  end
end

local function on_entity_built(event)
  register_entity(event.entity or event.created_entity or event.destination)
end

local function on_entity_removed(event)
  unregister_entity(event.entity)
end

script.on_init(function()
  ensure_storage()
  rescan_all()
end)

script.on_configuration_changed(function()
  ensure_storage()
  rescan_all()
end)

script.on_event(defines.events.on_built_entity, on_entity_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built)
script.on_event(defines.events.script_raised_built, on_entity_built)
script.on_event(defines.events.script_raised_revive, on_entity_built)
script.on_event(defines.events.on_entity_cloned, on_entity_built)

script.on_event(defines.events.on_pre_player_mined_item, on_entity_removed)
script.on_event(defines.events.on_robot_pre_mined, on_entity_removed)
script.on_event(defines.events.on_entity_died, on_entity_removed)
script.on_event(defines.events.script_raised_destroy, on_entity_removed)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting and string.sub(event.setting, 1, 11) == "real-steam-" then
    ensure_storage()
    rescan_all()
  end
end)

script.on_nth_tick(1800, function()
  rescan_all()
end)

script.on_nth_tick(6, function(event)
  if not settings.global["real-steam-enable-runtime-effects"].value then return end

  local interval = density_interval()
  if event.tick % interval ~= 0 then return end

  process_tracked_entities(event.tick)
end)

commands.add_command("real-steam-rescan", "Rebuild tracked Real Steam entities.", function(command)
  local player = command.player_index and game.get_player(command.player_index) or nil
  if player and not player.admin then
    player.print("Real Steam: only admins can run this command.")
    return
  end

  ensure_storage()
  rescan_all()

  local count = #storage.real_steam_keys
  if player then
    player.print("Real Steam: rebuilt tracking for " .. count .. " entities.")
  else
    log("Real Steam: rebuilt tracking for " .. count .. " entities.")
  end
end)
