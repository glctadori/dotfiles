-- Generato da theme-build; non modificare a mano.

vim.o.background = "light"

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "lodi"

local c = {
  background = "#f3ead7",
  surface    = "#e7dcc0",
  foreground = "#403a32",
  muted      = "#6a6357",
  accent     = "#4b6781",
  red        = "#9e4b3d",
  green      = "#57683f",
  yellow     = "#7d5f20",
  blue       = "#4b6781",
  purple     = "#77576f",
  cyan       = "#496b63",
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

-- Diagnostics
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

-- Windows
hl(0, "WinSeparator", { fg = c.surface })
hl(0, "VertSplit",    { fg = c.surface })

-- Markdown / Treesitter
hl(0, "@markup.heading.1", { fg = c.blue, bold = true })
hl(0, "@markup.heading.2", { fg = c.green, bold = true })
hl(0, "@markup.heading.3", { fg = c.purple, bold = true })
hl(0, "@markup.heading.4", { fg = c.cyan, bold = true })

hl(0, "@markup.link",       { fg = c.blue })
hl(0, "@markup.link.label", { fg = c.blue })
hl(0, "@markup.raw",        { fg = c.cyan })
hl(0, "@markup.list",       { fg = c.yellow })

-- Generic UI
hl(0, "Title",       { fg = c.blue, bold = true })
hl(0, "Directory",   { fg = c.blue })
hl(0, "Special",     { fg = c.cyan })
hl(0, "MatchParen",  { fg = c.background, bg = c.accent, bold = true })

hl(0, "Pmenu",       { fg = c.foreground, bg = c.surface })
hl(0, "PmenuSel",    { fg = c.background, bg = c.accent })
hl(0, "PmenuMatch",  { fg = c.blue, bold = true })

-- Snacks picker
hl(0, "SnacksPickerNormal",       { fg = c.foreground, bg = c.background })
hl(0, "SnacksPickerBorder",       { fg = c.muted, bg = c.background })
hl(0, "SnacksPickerTitle",        { fg = c.blue, bg = c.background, bold = true })
hl(0, "SnacksPickerDir",          { fg = c.muted })
hl(0, "SnacksPickerFile",         { fg = c.foreground })
hl(0, "SnacksPickerMatch",        { fg = c.blue, bold = true })
hl(0, "SnacksPickerCursorLine",   { bg = c.surface })

-- Markdown headings: colore, ma niente background
hl(0, "RenderMarkdownH1", { fg = c.blue,   bold = true })
hl(0, "RenderMarkdownH2", { fg = c.green,  bold = true })
hl(0, "RenderMarkdownH3", { fg = c.purple, bold = true })
hl(0, "RenderMarkdownH4", { fg = c.cyan,   bold = true })
hl(0, "RenderMarkdownH5", { fg = c.yellow, bold = true })
hl(0, "RenderMarkdownH6", { fg = c.muted,  bold = true })

for i = 1, 6 do
  hl(0, "RenderMarkdownH" .. i .. "Bg", {
    bg = c.background,
  })
end

-- Treesitter headings
hl(0, "@markup.heading.1", { fg = c.blue,   bold = true })
hl(0, "@markup.heading.2", { fg = c.green,  bold = true })
hl(0, "@markup.heading.3", { fg = c.purple, bold = true })
hl(0, "@markup.heading.4", { fg = c.cyan,   bold = true })
hl(0, "@markup.heading.5", { fg = c.yellow, bold = true })
hl(0, "@markup.heading.6", { fg = c.muted,  bold = true })

-- Markdown
hl(0, "@markup.link",       { fg = c.blue })
hl(0, "@markup.link.label", { fg = c.blue })
hl(0, "@markup.raw",        { fg = c.cyan })
hl(0, "@markup.list",       { fg = c.yellow })
hl(0, "@markup.strong",     { fg = c.foreground, bold = true })
hl(0, "@markup.italic",     { fg = c.purple, italic = true })

local heading_bg = {
  "#ded8c5", -- H1: grigio-blu tenue
  "#dde1c8", -- H2: verde tenue
  "#e4d6d8", -- H3: porpora tenue
  "#d7e1d8", -- H4: salvia tenue
  "#e8ddbd", -- H5: ocra tenue
  "#ddd7cc", -- H6
}

local heading_fg = {
  c.blue,
  c.green,
  c.purple,
  c.cyan,
  c.yellow,
  c.muted,
}

for i = 1, 6 do
  hl(0, "RenderMarkdownH" .. i, {
    fg = heading_fg[i],
    bold = true,
  })

  hl(0, "RenderMarkdownH" .. i .. "Bg", {
    bg = heading_bg[i],
  })
end

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
