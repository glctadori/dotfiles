hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "auto" })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto", mirror = "eDP-1" })
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.config({
    general = { layout = "master", gaps_in = 5, gaps_out = 8, border_size = 2, resize_on_border = true },
    decoration = {
        rounding = 8, rounding_power = 2, active_opacity = 1.0, inactive_opacity = 1.0,
        shadow = { enabled = true, range = 4, render_power = 3 },
        blur = { enabled = true, size = 8, passes = 2, vibrancy = 0.10 },
    },
    animations = { enabled = true },
    xwayland = { force_zero_scaling = true },
    misc = { disable_hyprland_logo = true, force_default_wallpaper = 0, focus_on_activate = true },
    master = { mfact = 0.55, new_status = "slave", new_on_top = false },
    input = {
        kb_layout = "it", repeat_delay = 300, repeat_rate = 50, follow_mouse = 1, sensitivity = 0,
        touchpad = { natural_scroll = true },
    },
})
hl.window_rule({
    name = "chatgpt-opacity", match = { class = "^brave-cadlkienfkclaiaibeoongdcgmdikeeg-Default$" },
    opacity = "0.95 0.92",
})
hl.window_rule({
    name = "udiskie-dialog", match = { class = "^udiskie$" },
    float = true, center = true, size = { 520, 260 },
})
hl.window_rule({
    name = "inbox-nvim", match = { class = "^inbox-nvim$" },
    float = true, center = true, size = { 900, 650 },
})
hl.window_rule({
    name = "dotfiles-install", match = { class = "^dotfiles-install$" },
    float = true, center = true, size = { 900, 650 },
})
hl.window_rule({
    name = "package-install", match = { class = "^package-install$" },
    float = true, center = true, size = { 900, 650 },
})
require(os.getenv("HOME") .. "/.config/theme/current/hyprland.lua")
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 95%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.0, bezier = "quick" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
