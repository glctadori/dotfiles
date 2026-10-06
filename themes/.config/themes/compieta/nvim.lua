vim.o.background = "dark"

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "compieta"

local c = {
  background = "#1c1714",
  surface    = "#2a211b",
  foreground = "#e3d9c6",
  muted      = "#6e6153",
  accent     = "#8ea9c8",
  red        = "#c2604f",
  green      = "#7d8b57",
  yellow     = "#c9a15a",
  blue       = "#8ea9c8",
  purple     = "#a98bb0",
  cyan       = "#7d9a8a",
}

local hl = vim.api.nvim_set_hl

-- Editor
hl(0, "Normal",       { fg = c.foreground, bg = c.background })
hl(0, "NormalFloat",  { fg = c.foreground, bg = c.surface })
hl(0, "FloatBorder",  { fg = c.muted, bg = c.surface })
hl(0, "LineNr",       { fg = c.muted })
hl(0, "CursorLineNr", { fg = c.accent, bold = true })
hl(0, "CursorLine",   { bg = c.surface })
hl(0, "Visual",       { bg = c.surface })
hl(0, "Search",       { fg = c.background, bg = c.yellow })

-- Syntax
hl(0, "Comment",    { fg = c.muted, italic = true })
hl(0, "String",     { fg = c.green })
hl(0, "Number",     { fg = c.yellow })
hl(0, "Boolean",    { fg = c.yellow })
hl(0, "Function",   { fg = c.blue })
hl(0, "Keyword",    { fg = c.purple })
hl(0, "Type",       { fg = c.cyan })
hl(0, "Identifier", { fg = c.foreground })
hl(0, "Operator",   { fg = c.accent })

-- Treesitter
hl(0, "@comment",  { link = "Comment" })
hl(0, "@string",   { link = "String" })
hl(0, "@number",   { link = "Number" })
hl(0, "@boolean",  { link = "Boolean" })
hl(0, "@function", { link = "Function" })
hl(0, "@keyword",  { link = "Keyword" })
hl(0, "@type",     { link = "Type" })
hl(0, "@variable", { fg = c.foreground })
hl(0, "@operator", { link = "Operator" })

-- LSP diagnostics
hl(0, "DiagnosticError", { fg = c.red })
hl(0, "DiagnosticWarn",  { fg = c.yellow })
hl(0, "DiagnosticInfo",  { fg = c.blue })
hl(0, "DiagnosticHint",  { fg = c.cyan })

-- mini.statusline
hl(0, "MiniStatuslineModeNormal", {
  fg = c.background,
  bg = c.blue,
  bold = true,
})

hl(0, "MiniStatuslineModeInsert", {
  fg = c.background,
  bg = c.green,
  bold = true,
})

hl(0, "MiniStatuslineModeVisual", {
  fg = c.background,
  bg = c.purple,
  bold = true,
})

hl(0, "MiniStatuslineModeReplace", {
  fg = c.background,
  bg = c.red,
  bold = true,
})

hl(0, "MiniStatuslineModeCommand", {
  fg = c.background,
  bg = c.yellow,
  bold = true,
})

hl(0, "MiniStatuslineModeOther", {
  fg = c.background,
  bg = c.cyan,
  bold = true,
})

hl(0, "MiniStatuslineDevinfo", {
  fg = c.muted,
  bg = c.surface,
})

hl(0, "MiniStatuslineFilename", {
  fg = c.foreground,
  bg = c.surface,
})

hl(0, "MiniStatuslineFileinfo", {
  fg = c.muted,
  bg = c.surface,
})

hl(0, "MiniStatuslineInactive", {
  fg = c.muted,
  bg = c.background,
})

-- Markdown headings
local heading_fg = {
  c.blue,
  c.green,
  c.purple,
  c.cyan,
  c.yellow,
  c.muted,
}

for i = 1, 6 do
  -- Testo del titolo
  hl(0, "RenderMarkdownH" .. i, {
    fg = heading_fg[i],
    bold = true,
  })

  -- Evidenziazione discreta
  hl(0, "RenderMarkdownH" .. i .. "Bg", {
    bg = c.surface,
  })
end

-- Treesitter headings
hl(0, "@markup.heading.1", { fg = c.blue,   bold = true })
hl(0, "@markup.heading.2", { fg = c.green,  bold = true })
hl(0, "@markup.heading.3", { fg = c.purple, bold = true })
hl(0, "@markup.heading.4", { fg = c.cyan,   bold = true })
hl(0, "@markup.heading.5", { fg = c.yellow, bold = true })
hl(0, "@markup.heading.6", { fg = c.muted,  bold = true })

-- Altri elementi Markdown
hl(0, "@markup.link",       { fg = c.blue })
hl(0, "@markup.link.label", { fg = c.blue })
hl(0, "@markup.raw",        { fg = c.cyan })
hl(0, "@markup.list",       { fg = c.yellow })
hl(0, "@markup.strong",     { fg = c.foreground, bold = true })
hl(0, "@markup.italic",     { fg = c.purple, italic = true })

-- Floating windows
hl(0, "NormalFloat", {
  fg = c.foreground,
  bg = c.background,
})

hl(0, "FloatBorder", {
  fg = c.muted,
  bg = c.background,
})

hl(0, "FloatTitle", {
  fg = c.foreground,
  bg = c.background,
  bold = true,
})

-- Snacks
hl(0, "SnacksNormal", {
  fg = c.foreground,
  bg = c.background,
})

hl(0, "SnacksNormalNC", {
  fg = c.foreground,
  bg = c.background,
})

hl(0, "SnacksPicker", {
  fg = c.foreground,
  bg = c.background,
})

hl(0, "SnacksPickerBorder", {
  fg = c.muted,
  bg = c.background,
})

hl(0, "SnacksPickerTitle", {
  fg = c.foreground,
  bg = c.background,
  bold = true,
})

hl(0, "SnacksPickerList", {
  fg = c.foreground,
  bg = c.background,
})

hl(0, "SnacksPickerPreview", {
  fg = c.foreground,
  bg = c.background,
})

hl(0, "SnacksPickerInput", {
  fg = c.foreground,
  bg = c.background,
})

hl(0, "SnacksPickerListCursorLine", {
  bg = c.surface,
})

hl(0, "SnacksPickerPreviewCursorLine", {
  bg = c.surface,
})
-- FzfLua
hl(0, "FzfLuaNormal", {
  fg = c.foreground,
  bg = c.background,
})

hl(0, "FzfLuaBorder", {
  fg = c.muted,
  bg = c.background,
})

hl(0, "FzfLuaTitle", {
  fg = c.foreground,
  bg = c.background,
  bold = true,
})

hl(0, "FzfLuaCursorLine", {
  fg = c.foreground,
  bg = c.surface,
})

hl(0, "FzfLuaCursorLineNr", {
  fg = c.accent,
  bg = c.surface,
  bold = true,
})

hl(0, "FzfLuaSearch", {
  fg = c.accent,
  bold = true,
})
