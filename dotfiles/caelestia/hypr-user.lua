local home = os.getenv("HOME")

-- Monitor layout: machine-specific, kept out of the repo in hypr-monitors.lua (install.sh moves existing rules there).
local monitors = io.open(home .. "/.config/caelestia/hypr-monitors.lua")
if monitors then
    monitors:close()
    require("hypr-monitors")
end

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

-- Fonds d'écran : studio intégré au shell (vidéos natives, transitions, couleurs par fond).
-- Super+Alt+W/X/C ouvrent le studio ; un second appui le referme.
for _, key in ipairs({ "SUPER + ALT + W", "SUPER + ALT + X", "SUPER + ALT + C" }) do
    hl.unbind(key)
    hl.bind(key, hl.dsp.global("caelestia:wallpapers"))
end

-- Presse-papiers : historique intégré au shell (cliphist), écouté par caelestia-clipboard.service.
for _, key in ipairs({ "SUPER + V", "SUPER + ALT + V" }) do
    hl.unbind(key)
    hl.bind(key, hl.dsp.global("caelestia:clipboard"))
end

-- Coller directement le dernier élément copié.
hl.unbind("CTRL + SHIFT + ALT + V")
hl.bind(
    "CTRL + SHIFT + ALT + V",
    hl.dsp.exec_cmd(home .. '/.local/bin/caelestia-clipboard-paste --id "$(cliphist list | head -n1 | cut -f1)"'),
    { locked = true }
)
