if not settings.startup["real-steam-replace-boiler-smoke"].value then
  return
end

if not (data.raw["trivial-smoke"] and data.raw["trivial-smoke"]["real-steam-pressure-puff"]) then
  return
end

local function patch_boiler_smoke(boiler)
  if not boiler or not boiler.energy_source or not boiler.energy_source.smoke then
    return
  end

  for _, smoke in pairs(boiler.energy_source.smoke) do
    if smoke.name then
      smoke.name = "real-steam-pressure-puff"
    end
    smoke.frequency = (smoke.frequency or 1) * 0.75
    smoke.starting_vertical_speed = (smoke.starting_vertical_speed or 0.08) * 0.75
    smoke.slow_down_factor = smoke.slow_down_factor or 1
  end
end

if data.raw["boiler"] then
  for _, boiler in pairs(data.raw["boiler"]) do
    patch_boiler_smoke(boiler)
  end
end
