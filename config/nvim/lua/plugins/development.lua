return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bashls = {},
        cssls = {},
        html = {},
        intelephense = { filetypes = { "php", "blade" } },
        tailwindcss = {
          filetypes_include = { "blade" },
          settings = { tailwindCSS = { includeLanguages = { blade = "html" } } },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "bash", "blade", "css", "html", "php_only", "toml" },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "blade-formatter",
        "pint",
        "rust-analyzer",
        "shellcheck",
        "php-debug-adapter",
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        php = { "pint", "php_cs_fixer", stop_after_first = true },
        blade = { "blade-formatter" },
        rust = { "rustfmt" },
      },
      formatters = {
        pint = {
          -- Only use Pint for Laravel projects or projects with their own Pint.
          condition = function(_, ctx)
            return vim.fs.root(ctx.dirname, { "artisan", "pint.json", "vendor/bin/pint" }) ~= nil
          end,
        },
      },
    },
  },
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")
      dap.configurations.php = {
        {
          name = "Listen for Xdebug",
          type = "php",
          request = "launch",
          port = 9003,
        },
      }
    end,
  },
}
