-- Native LSP and completion with project-aware Python interpreter selection.
local M = {}

function M.setup()
  local pixi = require("pixi_python")
  vim.lsp.config("pyright", {
    root_markers = { "pixi.toml", "pyproject.toml", "pyrightconfig.json", ".git" },
    before_init = function(params, config)
      local root = type(params.rootUri) == "string" and vim.uri_to_fname(params.rootUri) or config.root_dir
      local python = pixi.interpreter(root)
      if python then
        config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
          python = { pythonPath = python },
        })
      end
    end,
  })
  vim.lsp.config("lua_ls", {
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false },
        telemetry = { enable = false },
      },
    },
  })
  vim.lsp.config("marksman", { filetypes = { "markdown", "markdown.mdx", "vimwiki" } })
  vim.diagnostic.config({ virtual_text = false, signs = true, underline = true, severity_sort = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("minimal_lsp", { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if not client then
        return
      end
      if client.name == "ruff" then
        client.server_capabilities.hoverProvider = false
      end
      if
        vim.bo[event.buf].filetype ~= "markdown"
        and vim.bo[event.buf].filetype ~= "markdown.mdx"
        and vim.bo[event.buf].filetype ~= "vimwiki"
        and client:supports_method("textDocument/completion")
      then
        vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
      end
      local function map(key, action, desc)
        vim.keymap.set("n", key, action, { buffer = event.buf, desc = desc })
      end
      map("gd", vim.lsp.buf.definition, "Definition")
      map("gr", vim.lsp.buf.references, "References")
      map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
      map("<leader>ca", vim.lsp.buf.code_action, "Code action")
    end,
  })
end

return M
