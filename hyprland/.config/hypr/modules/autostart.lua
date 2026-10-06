hl.on("hyprland.start", function()
    for _, command in ipairs({
        "qs", "hyprpaper", "swayosd-server", "mako", "gammastep",
        "systemctl --user start hyprpolkitagent", "udiskie", "hyprsunset", "hypridle",
        "power-sound-monitor",
    }) do
        hl.exec_cmd(command)
    end
end)
