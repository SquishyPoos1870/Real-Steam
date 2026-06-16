data:extend({
  {
    type = "bool-setting",
    name = "real-steam-enable-runtime-effects",
    setting_type = "runtime-global",
    default_value = true,
    order = "a[effects]"
  },
  {
    type = "string-setting",
    name = "real-steam-density",
    setting_type = "runtime-global",
    default_value = "low",
    allowed_values = {"low", "balanced", "high"},
    order = "b[density]"
  },
  {
    type = "bool-setting",
    name = "real-steam-include-boilers",
    setting_type = "runtime-global",
    default_value = true,
    order = "c[boilers]"
  },

  {
    type = "bool-setting",
    name = "real-steam-include-pipes",
    setting_type = "runtime-global",
    default_value = true,
    order = "d[pipes]"
  },
  {
    type = "bool-setting",
    name = "real-steam-quality-reduces-leaks",
    setting_type = "runtime-global",
    default_value = true,
    order = "e[quality-reduces-leaks]"
  },
  {
    type = "bool-setting",
    name = "real-steam-weather-integration",
    setting_type = "runtime-global",
    default_value = true,
    order = "f[weather-integration]"
  },
  {
    type = "bool-setting",
    name = "real-steam-replace-boiler-smoke",
    setting_type = "startup",
    default_value = false,
    order = "g[boiler-smoke]"
  }
})
