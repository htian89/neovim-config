local M = {}

function M.grep_to_quickfix(pattern, opts)
  opts = opts or {}
  if vim.fn.executable("rg") == 0 then
    vim.notify("grep requires ripgrep (rg)", vim.log.levels.ERROR)
    return
  end

  pattern = pattern ~= "" and pattern or vim.fn.expand("<cword>")
  if pattern == "" then
    vim.notify("grep: empty pattern", vim.log.levels.WARN)
    return
  end

  local scopes = opts.scopes or { "." }
  local globs = opts.globs or {}
  local cmd = {
    "rg",
    "--vimgrep",
    "--fixed-strings",
    "--color=never",
    "--glob",
    "!tags",
    "--glob",
    "!*/tags",
  }

  for _, glob in ipairs(globs) do
    vim.list_extend(cmd, { "--glob", glob })
  end

  table.insert(cmd, pattern)
  vim.list_extend(cmd, scopes)

  local lines = vim.fn.systemlist(cmd)
  local title = string.format("%s %s in %s", opts.title or "grep", pattern, table.concat(scopes, ", "))
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
    "!dmp/streaming/**",
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
