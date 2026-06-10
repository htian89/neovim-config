local search = require("config.search")

local function switch_header_source()
  local current = vim.api.nvim_buf_get_name(0)
  if current == "" then
    vim.notify("Current buffer has no file name", vim.log.levels.WARN)
    return
  end

  local dir = vim.fn.fnamemodify(current, ":h")
  local base = vim.fn.fnamemodify(current, ":t:r")
  local ext = vim.fn.fnamemodify(current, ":e")
  local targets = vim.tbl_contains({ "c", "cc", "cpp", "cxx", "m", "mm" }, ext)
      and { "h", "hpp", "hh", "hxx" }
    or { "cc", "cpp", "cxx", "c" }

  for _, target_ext in ipairs(targets) do
    local target = dir .. "/" .. base .. "." .. target_ext
    if vim.fn.filereadable(target) == 1 then
      vim.cmd.edit(vim.fn.fnameescape(target))
      return
    end
  end

  vim.notify("No matching header/source file found for " .. base, vim.log.levels.WARN)
end

local function parse_grep_args(args)
  local parsed = {
    pattern = nil,
    regex = false,
    word = false,
  }
  local parts = args ~= "" and vim.fn.split(args) or {}
  local pattern_parts = {}

  for _, part in ipairs(parts) do
    if part == "-e" then
      parsed.regex = true
    elseif part == "-w" then
      parsed.word = true
    else
      local quote = part:sub(1, 1)
      if (quote == '"' or quote == "'") and part:sub(-1) == quote then
        part = part:sub(2, -2)
      end
      table.insert(pattern_parts, part)
    end
  end

  if #pattern_parts > 0 then
    parsed.pattern = table.concat(pattern_parts, " ")
  end

  return parsed
end

local function create_grep_command(name, opts)
  vim.api.nvim_create_user_command(name, function(command_opts)
    local parsed = parse_grep_args(command_opts.args)
    local command = vim.tbl_extend("force", opts, {
      scopes = opts.scope_fn and { opts.scope_fn() } or opts.scopes,
      regex = parsed.regex,
      word = parsed.word,
    })
    search.grep_to_quickfix(parsed.pattern, command)
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

vim.api.nvim_create_user_command("SwitchHeader", switch_header_source, {
  force = true,
  desc = "Switch between source file and same-name header",
})

vim.api.nvim_create_user_command("A", switch_header_source, {
  force = true,
  desc = "Switch between source file and same-name header",
})

vim.keymap.set("n", "<leader>h", switch_header_source, { desc = "Switch source/header" })

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
  globs = search.proto_globs(),
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
    globs = search.proto_globs(),
    desc = "Search current file level " .. scope_level .. " directory proto files with ripgrep",
  })
end

vim.keymap.set("n", "<F5>", function()
  pcall(vim.cmd.cnext)
end, { desc = "Quickfix next" })

vim.keymap.set("n", "<F6>", function()
  pcall(vim.cmd.cprev)
end, { desc = "Quickfix previous" })
