local base_smoke = data.raw["trivial-smoke"] and data.raw["trivial-smoke"]["smoke"]

if base_smoke then
  local function make_steam(name, color, duration, fade_in, fade_away, spread, start_scale, end_scale, slowdown, affected_by_wind)
    local steam = table.deepcopy(base_smoke)
    steam.name = name
    steam.duration = duration
    steam.fade_in_duration = fade_in
    steam.fade_away_duration = fade_away
    steam.spread_duration = spread
    steam.start_scale = start_scale
    steam.end_scale = end_scale
    steam.color = color
    steam.affected_by_wind = affected_by_wind
    steam.movement_slow_down_factor = slowdown
    steam.show_when_smoke_off = true
    return steam
  end

  data:extend({
    make_steam(
      "real-steam-soft-vapour",
      {r = 0.86, g = 0.90, b = 0.94, a = 0.15},
      60, 8, 30, 50, 0.10, 0.46, 0.986, true
    ),
    make_steam(
      "real-steam-pressure-puff",
      {r = 0.92, g = 0.95, b = 0.97, a = 0.145},
      46, 6, 24, 34, 0.085, 0.34, 0.988, true
    ),
    make_steam(
      "real-steam-turbine-mist",
      {r = 0.78, g = 0.86, b = 0.94, a = 0.13},
      72, 10, 36, 58, 0.10, 0.52, 0.988, true
    ),
    make_steam(
      "real-steam-cold-vapour",
      {r = 0.70, g = 0.84, b = 1.00, a = 0.115},
      64, 8, 34, 52, 0.095, 0.48, 0.988, true
    ),
    make_steam(
      "real-steam-pipe-whisper",
      {r = 0.92, g = 0.96, b = 1.00, a = 0.075},
      30, 3, 13, 18, 0.026, 0.115, 0.998, false
    ),
    make_steam(
      "real-steam-pipe-full-leak",
      {r = 0.90, g = 0.95, b = 1.00, a = 0.10},
      38, 4, 17, 24, 0.040, 0.185, 0.997, false
    ),
    make_steam(
      "real-steam-pipe-dribble",
      {r = 0.88, g = 0.94, b = 1.00, a = 0.055},
      22, 2, 9, 12, 0.016, 0.070, 0.999, false
    )
  })
end
