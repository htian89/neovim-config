local search = require("config.search")

local function create_grep_command(name, opts)
  vim.api.nvim_create_user_command(name, function(command_opts)
    local command = vim.tbl_extend("force", opts, {
      scopes = opts.scope_fn and { opts.scope_fn() } or opts.scopes,
    })
    search.grep_to_quickfix(command_opts.args, command)
  end, {
    nargs = "*",
    force = true,
    desc = opts.desc,
  })
end

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "\\g", function()
  search.grep_to_quickfix(vim.fn.expand("<cword>"), {
    title = "\\g",
    scopes = { search.current_level_scope(2) },
  })
end, { desc = "Search symbol under cursor" })

create_grep_command("Grep", {
  title = "Grep",
  scopes = { "." },
  desc = "Search all directories with ripgrep",
})

create_grep_command("Grepa", {
  title = "Grepa",
  scopes = { "huichuan/ad_server_v2" },
  desc = "Search huichuan/ad_server_v2 with ripgrep",
})

create_grep_command("Grept", {
  title = "Grept",
  scopes = { "huichuan/trigger_server_v2" },
  desc = "Search huichuan/trigger_server_v2 with ripgrep",
})

create_grep_command("Grepm", {
  title = "Grepm",
  scopes = { "huichuan/media_server" },
  desc = "Search huichuan/media_server with ripgrep",
})

create_grep_command("Grepe", {
  title = "Grepe",
  scopes = { "huichuan/exchange_server" },
  desc = "Search huichuan/exchange_server with ripgrep",
})

create_grep_command("Grepp", {
  title = "Grepp",
  scopes = { "." },
  globs = { "*.proto" },
  desc = "Search all proto files with ripgrep",
})

for level = 1, 4 do
  local scope_level = level
  create_grep_command("Grep" .. level, {
    title = "Grep" .. level,
    scope_fn = function()
      return search.current_level_scope(scope_level)
    end,
    desc = "Search current file level " .. scope_level .. " directory with ripgrep",
  })
end

for level = 1, 4 do
  local scope_level = level
  create_grep_command("Grepp" .. level, {
    title = "Grepp" .. level,
    scope_fn = function()
      return search.current_level_scope(scope_level)
    end,
    globs = { "*.proto" },
    desc = "Search current file level " .. scope_level .. " directory proto files with ripgrep",
  })
end

vim.keymap.set("n", "<F5>", function()
  pcall(vim.cmd.cnext)
end, { desc = "Quickfix next" })

vim.keymap.set("n", "<F6>", function()
  pcall(vim.cmd.cprev)
end, { desc = "Quickfix previous" })
