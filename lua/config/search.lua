local M = {}

function M.proto_globs()
  return { "*.proto", "!dmp/**" }
end

function M.resolve_pattern(pattern)
  if pattern and pattern ~= "" then
    return pattern
  end

  return vim.fn.expand("<cword>")
end

function M.grep_to_quickfix(pattern, opts)
  opts = opts or {}
  if vim.fn.executable("rg") == 0 then
    vim.notify("grep requires ripgrep (rg)", vim.log.levels.ERROR)
    return
  end

  pattern = M.resolve_pattern(pattern)
  if pattern == "" then
    vim.notify("grep: empty pattern", vim.log.levels.WARN)
    return
  end

  local scopes = opts.scopes or { "." }
  local globs = opts.globs or {}
  local cmd = {
    "rg",
    "--vimgrep",
    "--color=never",
    "--glob",
    "!tags",
    "--glob",
    "!*/tags",
  }

  if not opts.regex then
    table.insert(cmd, "--fixed-strings")
  end

  if opts.word then
    table.insert(cmd, "--word-regexp")
  end

  for _, glob in ipairs(globs) do
    vim.list_extend(cmd, { "--glob", glob })
  end

  table.insert(cmd, pattern)
  vim.list_extend(cmd, scopes)

  local lines = vim.fn.systemlist(cmd)
  local flags = {}
  if opts.regex then
    table.insert(flags, "regex")
  end
  if opts.word then
    table.insert(flags, "word")
  end
  local flag_text = #flags > 0 and " [" .. table.concat(flags, ", ") .. "]" or ""
  local title = string.format("%s%s %s in %s", opts.title or "grep", flag_text, pattern, table.concat(scopes, ", "))
  vim.fn.setqflist({}, "r", {
    title = title,
    lines = lines,
    efm = "%f:%l:%c:%m",
  })
  vim.cmd("copen")

  if #lines == 0 then
    vim.notify("No matches: " .. pattern, vim.log.levels.INFO)
  end
end

function M.current_level_scope(level)
  local file = vim.api.nvim_buf_get_name(0)
  local rel = file ~= "" and vim.fn.fnamemodify(file, ":.") or ""
  local parts = vim.split(rel, "/", { plain = true, trimempty = true })
  local scope_parts = {}

  for i = 1, math.min(level, #parts - 1) do
    table.insert(scope_parts, parts[i])
  end

  if #scope_parts > 0 then
    return table.concat(scope_parts, "/")
  end

  return "."
end

local function regex_escape(text)
  return text:gsub("([^%w_])", "%%%1")
end

local function gflag_symbol_under_cursor()
  local symbol = vim.fn.expand("<cword>")
  if symbol == "" then
    return nil
  end

  return symbol:gsub("^FLAGS_", "")
end

local function symbol_under_cursor()
  local symbol = vim.fn.expand("<cword>")
  if symbol == "" then
    return nil
  end
  return symbol
end

local function search_gflag_macro(flag_name, macro_prefix, scopes)
  local pattern = "\\b" .. macro_prefix .. "_[A-Za-z0-9_]+\\s*\\(\\s*" .. regex_escape(flag_name) .. "\\b"
  local cmd = {
    "rg",
    "--vimgrep",
    "--color=never",
    "--glob",
    "!tags",
    "--glob",
    "!*/tags",
    pattern,
  }
  vim.list_extend(cmd, scopes or { "." })
  return vim.fn.systemlist(cmd)
end

local function add_unique_path(paths, seen, path)
  if path == "" or seen[path] or vim.fn.filereadable(path) == 0 then
    return
  end

  seen[path] = true
  table.insert(paths, path)
end

local function gflag_fast_search_paths()
  local current = vim.api.nvim_buf_get_name(0)
  local paths = {}
  local seen = {}
  add_unique_path(paths, seen, current)

  local ext = vim.fn.fnamemodify(current, ":e")
  if vim.tbl_contains({ "h", "hh", "hpp", "hxx" }, ext) then
    local dir = vim.fn.fnamemodify(current, ":h")
    local base = vim.fn.fnamemodify(current, ":t:r")
    for _, source_ext in ipairs({ "cc", "cpp", "cxx", "c" }) do
      add_unique_path(paths, seen, dir .. "/" .. base .. "." .. source_ext)
    end
  end

  return paths
end

local function find_gflag_macro(flag_name, macro_prefix)
  local title_prefix = macro_prefix == "DEFINE" and "gflag definition " or "gflag declaration "

  for _, path in ipairs(gflag_fast_search_paths()) do
    local lines = search_gflag_macro(flag_name, macro_prefix, { path })
    if #lines > 0 then
      return lines, title_prefix .. flag_name
    end
  end

  local lines = search_gflag_macro(flag_name, macro_prefix)
  if #lines > 0 then
    return lines, title_prefix .. flag_name
  end

  return {}, title_prefix .. flag_name
end

local function cpp_definition_patterns(symbol)
  local escaped = regex_escape(symbol)
  return {
    "^\\s*#\\s*define\\s+" .. escaped .. "\\b",
    "^\\s*(extern\\s+)?(static\\s+)?(const|constexpr)\\b.*\\b" .. escaped .. "\\b\\s*(=|;)",
    "^\\s*(extern\\s+)?(static\\s+)?const\\b.*\\*\\s*" .. escaped .. "\\b\\s*(=|;)",
  }
end

local function search_cpp_symbol_definition(symbol, scopes)
  local lines = {}
  local seen = {}
  for _, pattern in ipairs(cpp_definition_patterns(symbol)) do
    local cmd = {
      "rg",
      "--vimgrep",
      "--color=never",
      "--glob",
      "!tags",
      "--glob",
      "!*/tags",
      pattern,
    }
    vim.list_extend(cmd, scopes or { "." })
    for _, line in ipairs(vim.fn.systemlist(cmd)) do
      if not seen[line] then
        seen[line] = true
        table.insert(lines, line)
      end
    end
  end
  return lines
end

local function find_cpp_symbol_definition(symbol)
  for _, path in ipairs(gflag_fast_search_paths()) do
    local lines = search_cpp_symbol_definition(symbol, { path })
    if #lines > 0 then
      return lines, "symbol definition " .. symbol
    end
  end

  local lines = search_cpp_symbol_definition(symbol)
  if #lines > 0 then
    return lines, "symbol definition " .. symbol
  end

  return {}, "symbol definition " .. symbol
end

function M.jump_gflag_definition()
  if vim.fn.executable("rg") == 0 then
    vim.notify("UH requires ripgrep (rg)", vim.log.levels.ERROR)
    return
  end

  local flag_name = gflag_symbol_under_cursor()
  if not flag_name or flag_name == "" then
    vim.notify("UH: no gflag under cursor", vim.log.levels.WARN)
    return
  end

  local lines, title = find_gflag_macro(flag_name, "DEFINE")
  if #lines == 0 then
    lines, title = find_gflag_macro(flag_name, "DECLARE")
  end

  if #lines == 0 then
    local symbol = symbol_under_cursor()
    if symbol then
      lines, title = find_cpp_symbol_definition(symbol:gsub("^FLAGS_", ""))
    end
  end

  if #lines == 0 then
    vim.notify("UH: no definition found for " .. flag_name, vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, "r", {
    title = title,
    lines = lines,
    efm = "%f:%l:%c:%m",
    idx = 1,
  })
  vim.cmd.cfirst()
end

local function open_proto_from_pb_header()
  local line = vim.api.nvim_get_current_line()
  local pb_header = line:match('[<"]([^<"]+%.pb%.h)[>"]')
  if not pb_header then
    return false
  end

  local proto = pb_header:gsub("%.pb%.h$", ".proto")
  proto = proto:gsub("^build/pb/c%+%+/", "")

  local candidates = {
    proto,
    vim.fn.fnamemodify(proto, ":t"),
  }

  for _, candidate in ipairs(candidates) do
    local found = vim.fn.findfile(candidate, ".;")
    if found ~= "" and vim.fn.filereadable(found) == 1 then
      vim.cmd.edit(vim.fn.fnameescape(found))
      return true
    end
  end

  vim.notify("Proto not found for " .. pb_header, vim.log.levels.WARN)
  return false
end

local function jump_proto_symbol()
  if vim.fn.executable("rg") == 0 then
    return false
  end

  local symbol = vim.fn.expand("<cword>")
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col(".")
  local namespace_symbol = nil

  for start_col, name in line:gmatch("()([%w_]+::[%w_:]+)") do
    local end_col = start_col + #name
    if col >= start_col and col <= end_col then
      namespace_symbol = name:match("([%w_]+)$")
      break
    end
  end

  symbol = namespace_symbol or symbol
  if symbol == "" then
    return false
  end

  local pattern = "\\b(message|enum|service)\\s+" .. symbol .. "\\b"
  local lines = vim.fn.systemlist({
    "rg",
    "--vimgrep",
    "--color=never",
    "--glob",
    "*.proto",
    "--glob",
    "!tags",
    "--glob",
    "!*/tags",
    "--glob",
    "!dmp/**",
    pattern,
    ".",
  })

  if #lines == 0 then
    return false
  end

  table.sort(lines, function(left, right)
    local function score(line_text)
      if line_text:match("^%./huichuan/") or line_text:match("^huichuan/") then
        return 0
      end
      if line_text:match("^%./common/") or line_text:match("^common/") then
        return 1
      end
      return 2
    end

    local left_score = score(left)
    local right_score = score(right)
    if left_score == right_score then
      return left < right
    end
    return left_score < right_score
  end)

  vim.fn.setqflist({}, "r", {
    title = "proto definition " .. symbol,
    lines = lines,
    efm = "%f:%l:%c:%m",
    idx = 1,
  })
  vim.cmd.cfirst()
  return true
end

function M.smart_definition()
  if open_proto_from_pb_header() then
    return
  end

  if jump_proto_symbol() then
    return
  end

  vim.lsp.buf.definition()
end

return M
