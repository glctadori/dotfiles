-- Hyprland 0.56: entrypoint minimale. I moduli condividono le API globali hl.
local config_dir = os.getenv("HOME") .. "/.config/hypr/modules/"

for _, module in ipairs({ "appearance", "autostart", "bindings", "workspaces" }) do
    dofile(config_dir .. module .. ".lua")
end
