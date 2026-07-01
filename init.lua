-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
local function AlternateColorColumn(...)
  local args = { ... }

  if #args > 0 then
    vim.opt.colorcolumn = tostring(tonumber(args[1]) + 1)
  elseif vim.o.colorcolumn ~= "" and vim.o.colorcolumn ~= "0" then
    vim.opt.colorcolumn = ""
  else
    vim.opt.colorcolumn = "111"
  end
end

AlternateColorColumn(110)
vim.api.nvim_create_user_command("CC", function(opts)
  if #opts.fargs > 0 then
    AlternateColorColumn(opts.fargs[1])
  else
    AlternateColorColumn()
  end
end, {
  nargs = "?",
  bang = true,
})
