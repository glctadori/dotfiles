local M = {}

function M.setup()
  vim.lsp.config("pyright", {
    root_markers = {
      "pyproject.toml",
      "pyrightconfig.json",
      ".git",
    },
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

  vim.lsp.config("marksman", {
    filetypes = { "markdown", "markdown.mdx", "vimwiki" },
  })

  vim.diagnostic.config({
    virtual_text = false,
    signs = true,
    underline = true,
    severity_sort = true,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("lsp", { clear = true }),
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if not client then
        return
      end

      -- Ruff non deve sostituire Pyright per hover
      if client.name == "ruff" then
        client.server_capabilities.hoverProvider = false
      end

      -- Completion nativa
      if
        vim.bo[event.buf].filetype ~= "markdown"
        and vim.bo[event.buf].filetype ~= "markdown.mdx"
        and vim.bo[event.buf].filetype ~= "vimwiki"
        and client:supports_method("textDocument/completion")
      then
        vim.lsp.completion.enable(true, client.id, event.buf, {
          autotrigger = true,
        })
      end

      require("keymaps").lsp(event.buf)
    end,
  })
end

return M
