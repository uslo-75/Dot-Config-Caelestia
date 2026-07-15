local home = os.getenv("HOME")

-- Keyboard and workspaces: French AZERTY top row.
hl.config({
    input = {
        kb_layout = "fr",
        kb_variant = "",
        kb_options = "",
    },
})

local azerty_ws_keys = {
    "code:10", -- &
    "code:11", -- é
    "code:12", -- "
    "code:13", -- '
    "code:14", -- (
    "code:15", -- -
    "code:16", -- è
    "code:17", -- _
    "code:18", -- ç
    "code:19", -- à
}

for i, key in ipairs(azerty_ws_keys) do
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind("SUPER + ALT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- NVIDIA variables are only exported on an NVIDIA host.
local nvidia = io.open("/proc/driver/nvidia/version")
if nvidia then
    nvidia:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
end

-- Applications.
hl.unbind("SUPER + T")
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))
hl.unbind("SUPER + W")
hl.bind("SUPER + W", hl.dsp.exec_cmd("zen-browser"))

-- Waypaper and dynamic Caelestia themes.
hl.exec_cmd(home .. "/.local/bin/waypaper-restore-safe 3 &")

hl.window_rule({
    match = { class = ".*[Ww]aypaper.*" },
    float = true,
    size = {1500, 880},
    center = true,
})

hl.window_rule({
    match = { title = ".*[Ww]aypaper.*" },
    float = true,
    size = {1500, 880},
    center = true,
})

hl.layer_rule({
    match = { namespace = "mpvpaper" },
    no_anim = true,
})

hl.on("hyprland.start", function()
    hl.exec_cmd(home .. "/.local/bin/waypaper-restore-safe 1")
    hl.exec_cmd("sleep 2; " .. home .. "/.local/bin/caelestia-waypaper-apply")
end)

hl.unbind("SUPER + ALT + W")
hl.bind("SUPER + ALT + W", hl.dsp.exec_cmd(home .. "/.local/bin/caelestia-wallpaper-menu"))
hl.unbind("SUPER + ALT + X")
hl.bind("SUPER + ALT + X", hl.dsp.exec_cmd(home .. "/.local/bin/waypaper-open"))
hl.unbind("SUPER + ALT + C")
hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd(home .. "/.local/bin/caelestia-theme-menu"))

-- Clipse GUI owns clipboard history. Stop Caelestia's cliphist watchers.
hl.on("hyprland.start", function()
    hl.exec_cmd([[sleep 0.2; pkill -f "wl-paste.*cliphist store" || true]])
    hl.exec_cmd(home .. "/.local/bin/cg-open --ensure-listener")
end)

hl.window_rule({
    match = { title = ".*Clipse.*" },
    float = true,
    size = {950, 720},
    center = true,
})

hl.window_rule({
    match = { class = ".*clipse.*" },
    float = true,
    size = {950, 720},
    center = true,
})

hl.unbind("SUPER + V")
hl.bind("SUPER + V", hl.dsp.exec_cmd(home .. "/.local/bin/cg-open"), { release = true })
hl.unbind("SUPER + ALT + V")
hl.bind("SUPER + ALT + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
