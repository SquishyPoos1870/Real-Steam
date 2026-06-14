# Real Steam

**Real Steam** adds extra steam ambience to boilers, steam engines, steam turbines, heat exchangers, and steam pipes so your factory feels more alive.

Instead of everything looking perfectly sealed and static, steam systems can now hiss, vent, and leak lightly under pressure.

Build cleaner. Feel more industry. Keep your steam setups looking active and believable.

---

## 🎥 Demo Video

![Real Steam demo](https://raw.githubusercontent.com/SquishyPoos1870/-Real-Steam/main/Factorio%202026.06.13%20-%2018.35.53.02.mp4)

Watch **Real Steam** in action with extra steam ambience, pipe hiss, and subtle industrial venting.

---

## ⚙️ What It Does

**Real Steam** gives your steam-based machines and pipes extra visual life.

Boilers, heat exchangers, steam engines, and steam turbines can emit additional steam effects while working. Steam pipes can also show small leaks and vent points, especially around heavier pressure areas like pipe-to-ground joins.

The goal is not to turn your base into a smoke cloud — it is to make steam systems feel more mechanical, active, and believable while still fitting the normal Factorio style.

This Factorio 2.0 version includes cleaner runtime handling, improved rescanning, better entity tracking, more controlled leak behaviour, and optional compatibility for IR3 Assets: steamworks so the effect stays immersive without becoming messy.

---

## ✅ Features

- 💨 Extra steam ambience for:
  - Boilers
  - Heat Exchangers
  - Steam Engines
  - Steam Turbines

- 🔧 Optional steam pipe leaks
- 🔥 Optional boiler smoke replacement
- 🌫️ Fuller steam systems can vent a bit more heavily
- 🧩 Pipe-to-ground joins can act as natural leak points
- ⚙️ Runtime settings for effect density and enabled sources
- ♻️ Clean entity tracking for built, mined, destroyed, cloned, and revived entities
- 🔄 Includes `/real-steam-rescan` admin command
- ✅ Factorio 2.0 compatible
- ✅ IR3 Assets: steamworks compatibility
- 🧼 Cleaned and repackaged for modern Factorio

---

## 🛠️ Settings

This mod includes runtime settings so you can tune the look to your liking:

| Setting | What It Does |
|---|---|
| Steam Density | Controls how strong and frequent the extra effects are |
| Include Boilers | Enables extra steam effects for boilers |
| Include Steam Pipes | Enables steam leaks/hiss effects on pipes |
| Replace Boiler Smoke | Replaces the default boiler smoke style with the modded effect |

**Recommended starting point:**

- Steam Density: **Balanced**
- Include Boilers: **On**
- Include Steam Pipes: **On**
- Replace Boiler Smoke: **Off**

This gives a cleaner, more natural industrial look.

---

## 🧪 Behaviour Notes

- Steam engines and turbines only emit extra steam when they are actually working.
- Pipe leaks are meant to be subtle and atmospheric, not constant across every pipe.
- Pipe-to-ground sections are more likely to show light venting or hiss points.
- The mod is designed to stay lightweight and practical for normal gameplay.

---

## 🔄 Rescan Command

If your steam network ever needs to be rebuilt or refreshed, you can run:

```text
/real-steam-rescan
```

This forces the mod to rescan valid steam entities.

---

## 📌 Design Goal

The aim of **Real Steam** is to make steam builds feel more alive without going over the top.

It is meant to sit somewhere between **vanilla Factorio** and a more immersive industrial look:

- more active than vanilla
- more believable than random puffs everywhere
- still clean enough to use in real factories

---

## 🙏 Credits

- Mod maintained and polished by **Squishy1870**
- Built using Factorio base-game smoke prototypes as the foundation for custom steam-style vapour effects

Factorio is made by Wube Software. This is an independent fan-made mod and is not affiliated with or endorsed by Wube Software.

---

## 📜 License

GNU General Public License v3.0.


Compatibility: Real Steam 1.0.19 adds crash-safe support for IR3 Assets: steamworks steam pipes, copper boilers, steam pumps, small steam tanks, and steam-powered machines. No IR3 code or assets are copied.


Compatibility note: missing or disabled optional IR3 prototype names are skipped safely at runtime, so partial IR3 asset-pack setups should not crash Real Steam.
