return {
  {
    "ishiooon/codex.nvim",
    dependencies = { "folke/snacks.nvim" },
    cmd = {
      "Codex",
      "CodexFocus",
      "CodexSend",
      "CodexTreeAdd",
    },
    keys = {
      { "<leader>cc", "<cmd>Codex<cr>", desc = "Codex: Toggle" },
      { "<leader>cf", "<cmd>CodexFocus<cr>", desc = "Codex: Focus" },
      { "<leader>cs", "<cmd>CodexSend<cr>", mode = "v", desc = "Codex: Send selection" },
      {
        "<leader>cs",
        "<cmd>CodexTreeAdd<cr>",
        desc = "Codex: Add file",
        ft = { "neo-tree", "neo-tree-popup", "oil" },
      },
    },
    opts = {
      terminal_cmd = "codex",
      env = {
        ENABLE_IDE_INTEGRATION = "true",
        CODEX_CODE_SSE_PORT = "12345",
      },
    },
  },
}
