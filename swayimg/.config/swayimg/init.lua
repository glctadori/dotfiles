-- Niente informazioni sopra l'immagine
swayimg.text.visible = false

-- Viewer ------------------------------------------------

-- immagini precedente / successiva
swayimg.viewer.on_key("h", function()
    swayimg.viewer.open("prev")
end)

swayimg.viewer.on_key("l", function()
    swayimg.viewer.open("next")
end)

-- prima / ultima immagine
swayimg.viewer.on_key("g", function()
    swayimg.viewer.open("first")
end)

swayimg.viewer.on_key("Shift-g", function()
    swayimg.viewer.open("last")
end)

-- Gallery ------------------------------------------------

swayimg.gallery.on_key("h", function()
    swayimg.gallery.select("left")
end)

swayimg.gallery.on_key("j", function()
    swayimg.gallery.select("down")
end)

swayimg.gallery.on_key("k", function()
    swayimg.gallery.select("up")
end)

swayimg.gallery.on_key("l", function()
    swayimg.gallery.select("right")
end)

swayimg.viewer.on_key("q", function()
    swayimg.exit()
end)

swayimg.gallery.on_key("q", function()
    swayimg.exit()
end)

swayimg.slideshow.on_key("q", function()
    swayimg.exit()
end)
