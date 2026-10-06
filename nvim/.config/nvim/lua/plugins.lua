-- Explicit plugin selection: navigation, language support, Markdown and Git hunks.
local function root()
  return vim.fs.root(0, { ".git", "pixi.toml", "pyproject.toml", "platformio.ini" }) or vim.fn.getcwd()
end

local parsers = {
  "bash",
  "c",
  "cpp",
  "json",
  "latex",
  "lua",
  "markdown",
  "markdown_inline",
  "python",
  "toml",
  "vim",
  "vimdoc",
  "yaml",
}

return {
  {
    "neanias/everforest-nvim",
    lazy = false,
    priority = 1100,
    opts = { background = "medium" },
    config = function(_, opts)
      require("everforest").setup(opts)
      -- vim.cmd.colorscheme("everforest")
    end,
  },
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
  },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
  },
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
  },
  -- { "nvim-mini/mini.icons", opts = {} },
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      require("mini.icons").setup()

      local statusline = require("mini.statusline")

      statusline.setup({
        content = {
          active = function()
            local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
            local git = statusline.section_git({ trunc_width = 75 })
            local filename = statusline.section_filename({ trunc_width = 140 })
            local location = statusline.section_location({ trunc_width = 75 })

            local icon = ""
            local name = vim.api.nvim_buf_get_name(0)

            if name ~= "" then
              local ext = vim.fn.fnamemodify(name, ":e")
              local file_icon = MiniIcons.get("extension", ext)
              icon = file_icon and (file_icon .. " ") or ""
            end

            local modified = vim.bo.modified and " ●" or ""

            local ai = ""
            if vim.g.ai_status and vim.g.ai_status ~= "" then
              ai = "✦ " .. vim.g.ai_status
            end

            return statusline.combine_groups({
              {
                hl = mode_hl,
                strings = { mode },
              },

              "%<",

              {
                hl = "MiniStatuslineFilename",
                strings = {
                  icon .. filename .. modified,
                },
              },

              {
                hl = "MiniStatuslineDevinfo",
                strings = { git },
              },

              "%=",

              {
                hl = "MiniStatuslineDevinfo",
                strings = { ai },
              },

              {
                hl = "MiniStatuslineFileinfo",
                strings = { location },
              },
            })
          end,
        },
      })

      -- Una sola statusline anche con split/chat
      vim.opt.laststatus = 3

      -- Mini mostra già la modalità
      vim.opt.showmode = false
    end,
  },
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 1000,
    dependencies = { "nvim-mini/mini.icons" },
    init = function()
      if vim.env.KITTY_WINDOW_ID and vim.env.KITTY_WINDOW_ID ~= "" and not vim.env.SNACKS_KITTY then
        vim.env.SNACKS_KITTY = "true"
      end
    end,
    opts = {
      picker = { enabled = true, hidden = true, sources = { files = { hidden = true } } },
      explorer = { enabled = true },
      image = { enabled = true, doc = { inline = true } },
      input = { enabled = true },
      notifier = { enabled = true },
    },
    config = function(_, opts)
      local snacks = require("snacks")
      opts.image.formats = vim.deepcopy(snacks.config.image.formats)
      table.insert(opts.image.formats, "svg")
      snacks.setup(opts)
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    -- The frozen master branch supports Ubuntu 26.04's Neovim 0.11.
    branch = "master",
    commit = "cf12346a3414fa1b06af75c79faebe7f76df080a",
    build = ":TSUpdate",
    config = function()
      -- The pinned LaTeX grammar uses ABI 14; newer CLIs removed --no-bindings.
      require("nvim-treesitter.install").ts_generate_args = {
        "generate", "--abi", "14",
      }
      require("nvim-treesitter.configs").setup({
        ensure_installed = parsers,
        highlight = { enable = true },
      })
      vim.treesitter.language.register("markdown", "vimwiki")
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "markdown.mdx", "vimwiki", "codecompanion" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" },
    opts = {
      file_types = { "markdown", "markdown.mdx", "vimwiki", "codecompanion" },
      latex = {
        enabled = false,
        --   converter = { "utftex", "latex2text" },
        --   -- position = "above",
      },
      heading = { sign = false },
      code = { sign = false, width = "block", right_pad = 1 },
    },
    keys = {
      {
        "<leader>um",
        function()
          require("render-markdown").toggle()
        end,
        desc = "Toggle Markdown rendering",
      },
    },
  },
  {
    "vimwiki/vimwiki",
    branch = "dev",
    init = function()
      vim.g.vimwiki_list = {
        {
          path = "~/projects/notes",
          index = "index",
          syntax = "markdown",
          ext = ".md",
          diary_rel_path = "diary/",
          diary_index = "Diary",
        },
      }
      vim.g.vimwiki_global_ext = 0
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(buf)
        require("keymaps").gitsigns(buf)
      end,
    },
  },
  {
    "stevearc/conform.nvim",
    cmd = "ConformInfo",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        sh = { "shfmt" },
        python = { "ruff_format" },
      },
      default_format_opts = {
        lsp_format = "fallback",
        timeout_ms = 3000,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "mason-org/mason.nvim", opts = {}, cmd = "Mason" },
      "mason-org/mason-lspconfig.nvim",
    },
    config = function()
      require("lsp").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright", "ruff", "clangd", "bashls", "lua_ls", "marksman" },
        automatic_enable = { "pyright", "ruff", "clangd", "bashls", "lua_ls", "marksman" },
      })
    end,
  },
  {
    "NeogitOrg/neogit",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Neogit",
    opts = {},
  },
}
