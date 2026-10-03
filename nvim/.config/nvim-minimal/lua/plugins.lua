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
      vim.cmd.colorscheme("everforest")
    end,
  },
  { "nvim-mini/mini.icons", opts = {} },
  {
    "olimorris/codecompanion.nvim",
    version = "^19.0.0",
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions", "CodeCompanionCodeReview" },
    dependencies = { "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter" },
    opts = {
      adapters = {
        http = {
          openrouter = function()
            return require("codecompanion.adapters").extend("openrouter", {
              env = {
                -- Inserisci manualmente la tua API key OpenRouter tra le virgolette.
                -- api_key = """
              },
              schema = {
                model = {
                  default = "deepseek/deepseek-v4.1-flash",
                },
              },
            })
          end,
        },
      },
      interactions = {
        chat = { adapter = "openrouter" },
        inline = { adapter = "openrouter" },
        cmd = { adapter = "openrouter" },
        background = { adapter = "openrouter" },
      },
    },
    keys = {
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "AI actions" },
      { "<leader>ac", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Toggle AI chat" },
      { "<leader>as", "<cmd>CodeCompanionChat Add<cr>", mode = "v", desc = "Add selection to AI chat" },
      { "<leader>ar", "<cmd>CodeCompanionCodeReview<cr>", desc = "Review AI changes" },
    },
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
    },
    config = function(_, opts)
      local snacks = require("snacks")
      opts.image.formats = vim.deepcopy(snacks.config.image.formats)
      table.insert(opts.image.formats, "svg")
      snacks.setup(opts)
    end,
    keys = {
      {
        "<leader>ff",
        function()
          Snacks.picker.files({ cwd = root() })
        end,
        desc = "Find files",
      },
      {
        "<leader>e",
        function()
          Snacks.explorer({ cwd = root() })
        end,
        desc = "File explorer",
      },
      {
        "<leader>sh",
        function()
          Snacks.picker.help()
        end,
        desc = "Help",
      },
    },
  },
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    dependencies = { "nvim-mini/mini.icons" },
    opts = {
      grep = { rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden -g !.git" },
    },
    keys = {
      {
        "<leader>bb",
        function()
          require("fzf-lua").buffers()
        end,
        desc = "Find buffers (fzf)",
      },
      {
        "<leader>sg",
        function()
          require("fzf-lua").live_grep({ cwd = root() })
        end,
        desc = "Search project (ripgrep + fzf)",
      },
    },
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
      latex = { enabled = true, converter = { "latex2text" } },
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
      vim.g.vimwiki_list = { { path = "~/Projects/notes", index = "index", syntax = "markdown", ext = ".md" } }
      vim.g.vimwiki_global_ext = 0
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(key, action, desc)
          vim.keymap.set("n", key, action, { buffer = buf, desc = desc })
        end
        map("]h", function()
          gs.nav_hunk("next")
        end, "Next hunk")
        map("[h", function()
          gs.nav_hunk("prev")
        end, "Previous hunk")
        map("<leader>hp", gs.preview_hunk, "Preview hunk")
        map("<leader>hs", gs.stage_hunk, "Stage hunk")
        map("<leader>hr", gs.reset_hunk, "Reset hunk")
      end,
    },
  },
  {
    "stevearc/conform.nvim",
    cmd = "ConformInfo",
    opts = {
      formatters_by_ft = { lua = { "stylua" }, sh = { "shfmt" }, python = { "ruff_format" } },
      default_format_opts = { lsp_format = "fallback", timeout_ms = 3000 },
    },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format()
        end,
        mode = { "n", "v" },
        desc = "Format explicitly",
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
      require("config.lsp").setup()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright", "ruff", "clangd", "bashls", "lua_ls", "marksman" },
        automatic_enable = { "pyright", "ruff", "clangd", "bashls", "lua_ls", "marksman" },
      })
    end,
  },
}
