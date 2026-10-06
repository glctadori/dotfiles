local mod = "SUPER"
local terminal = "kitty"
local browser = "brave"

hl.bind(mod .. " + J", hl.dsp.layout("cyclenext"))
hl.bind(mod .. " + K", hl.dsp.layout("cycleprev"))
hl.bind(mod .. " + SHIFT + J", hl.dsp.layout("swapnext noloop"))
hl.bind(mod .. " + SHIFT + K", hl.dsp.layout("swapprev noloop"))
hl.bind(mod .. " + H", hl.dsp.layout("mfact -0.05"))
hl.bind(mod .. " + L", hl.dsp.layout("mfact +0.05"))
hl.bind(mod .. " + SPACE", hl.dsp.layout("swapwithmaster auto"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())

local programs = {
    { mod .. " + RETURN", "project-spawn terminal" },
    { mod .. " + A", "project-spawn agent" },
    { mod .. " + SHIFT + RETURN", "add-to-inbox --open" },
    { mod .. " + D", "qs ipc call launcher toggle" },
    { mod .. " + SHIFT + D", "palette" },
    { mod .. " + W", browser },
    { mod .. " + N", terminal .. " nvim -c VimwikiIndex" },
    { mod .. " + R", terminal .. " yazi" },
    { mod .. " + SHIFT + R", terminal .. " btm" },
    { mod .. " + M", "qs ipc call playlists toggle" },
    { mod .. " + SHIFT + M", terminal .. " ncmpcpp" },
    { mod .. " + E", terminal .. " neomutt" },
    { mod .. " + T", "pomodoro toggle" },
    { mod .. " + C", "brave --app=https://chatgpt.com" },
    { mod .. " + SHIFT + C", "project-spawn agent" },
    { mod .. " + I", "add-to-inbox" },
    { mod .. " + SHIFT + I", "package-install" },
    { mod .. " + SHIFT + N", terminal .. " newsboat" },
    { mod .. " + CTRL + L", "hyprlock" },
    { mod .. " + SHIFT + S", "loginctl lock-session && systemctl suspend" },
    { mod .. " + SHIFT + Q", "project-session close" },
    { mod .. " + SHIFT + W", "wifi-reconnect" },
    { mod .. " + F12", "theme select" },
    { mod .. " + P", "mpc toggle" },
    { mod .. " + SHIFT + P", "project-session open" },
    { mod .. " + SHIFT + Y", "qs ipc call youtube toggle" },
}
for _, binding in ipairs(programs) do
    hl.bind(binding[1], hl.dsp.exec_cmd(binding[2]))
end

hl.bind("PRINT", hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | wl-copy']]))
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd([[grim - | wl-copy]]))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(
    [[sh -c 'dir="$(xdg-user-dir PICTURES)/Screenshots"; mkdir -p "$dir"; grim -g "$(slurp)" "$dir/$(date +%Y-%m-%d_%H-%M-%S).png"']]
))
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
