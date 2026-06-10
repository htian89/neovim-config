return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      vim.api.nvim_create_user_command("Gd", function()
        require("config.search").smart_definition()
      end, {
        force = true,
        desc = "Goto definition, including proto",
      })
    end,
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.clangd = vim.tbl_deep_extend("force", opts.servers.clangd or {}, {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--completion-style=detailed",
          "--header-insertion=iwyu",
          "--pch-storage=memory",
        },
        filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "c", "cpp", "proto" })
    end,
  },
}
