# havoc public — arsenal pack

> public release client for roblox arsenal. built on top of the havoc ui framework with aimlock, esp, hitbox expansion, and gun mods.

```text
language : luau
version  : v1.1.0
status   : active
```

---

### quick start

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/yentheterrible/arsenal/main/arsenal.lua"))()
```

---

### features

#### combat & aim
- **aimlock** : configurable smoothing, prediction, fov ring, fov radius, target part selection, and team check.
- **orbit** : target-orbit script with customizable radius, height, and rotation speed.

#### visuals & esp
- **player highlight** : customizable fill transparency and color outline.
- **overlays** : custom 2d box, tracer lines, display names, and team color toggles.
- **hitbox expander** : configurable part size, transparency, no-collision mode, and team check (ffa / team).
- **object esp** : live distance tracking for dropped ammo boxes and health jars.

#### gun mods & skins
- **gun mods** : fast reload, fast fire rate, continuous auto-fire, zero spread, zero recoil, and infinite ammo (v1/v2).
- **skins & charms** : custom arm/gun materials and colors (forcefield, plastic, wood, grass) and dynamic rainbow mesh cycling.

#### movement & utility
- **movement** : custom walkspeed & jumppower overrides (velocity, vector, or cframe modes), infinite jump, and flight module.
- **anti-aim** : customizable body-spin anti-aim with variable rotation speeds.
- **misc** : xray mode, fullbright, role-tag spoofing, killfeed name spoofing, and fps/anti-lag performance toggles.

---

### tech & architecture

- **state management** : clean cleanup routines on window destroy or respawn to avoid memory leaks.
- **non-intrusive UI** : built-in viewport scaling, responsive drag-and-drop header, and real-time network metrics.
- **error-safe** : wrapped in pcall/xpcall execution layers to isolate environment runtime errors.

---

### socials

- **discord** : [convictedx](https://discord.com/users/convictedx)
- **email** : [yenthet3rrible@gmail.com](mailto:yenthet3rrible@gmail.com)
- **github** : [@yentheterrible](https://github.com/yentheterrible/arsenal)