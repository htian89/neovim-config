-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_user_command("Rbuild", function(opts)
  if vim.g.rbuild_job_id then
    vim.notify("Rbuild is already running. Use :RbuildStop first.", vim.log.levels.WARN)
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("Rbuild: current buffer has no file", vim.log.levels.ERROR)
    return
  end

  local rel = vim.fn.fnamemodify(file, ":.")
  local cmd = { "/Users/yimu/.vim/mac-tools/rbuild", "-f", rel }
  vim.list_extend(cmd, opts.fargs)

  local title = table.concat(cmd, " ")
  local efm = table.concat({
    "%f:%l:%c: %trror: %m",
    "%f:%l:%c: %tarning: %m",
    "%f:%l:%c: %m",
    "%f:%l: %trror: %m",
    "%f:%l: %tarning: %m",
    "%f:%l: %m",
  }, ",")

  vim.fn.setqflist({}, "r", { title = title, lines = { "$ " .. title }, efm = efm })
  vim.cmd("botright copen")
  vim.notify("Rbuild started: " .. rel, vim.log.levels.INFO)

  local function append_qf(data)
    if not data then
      return
    end

    local lines = vim.tbl_filter(function(line)
      return line ~= ""
    end, data)

    if #lines > 0 then
      vim.fn.setqflist({}, "a", { lines = lines, efm = efm })
    end
  end

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      append_qf(data)
    end,
    on_stderr = function(_, data)
      append_qf(data)
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        local stopped = vim.g.rbuild_stopping
        vim.g.rbuild_job_id = nil
        vim.g.rbuild_stopping = nil

        if stopped then
          vim.fn.setqflist({}, "a", {
            items = { { text = "[Rbuild stopped]" } },
          })
          vim.cmd("botright copen")
          return
        end

        vim.fn.setqflist({}, "a", {
          lines = { string.format("[Rbuild exited with code %d]", code) },
          efm = efm,
        })

        vim.cmd("botright copen")
        if code == 0 then
          vim.notify("Rbuild finished", vim.log.levels.INFO)
          return
        end

        local items = vim.fn.getqflist()
        for i, item in ipairs(items) do
          if item.valid == 1 then
            vim.fn.setqflist({}, "a", { idx = i })
            vim.cmd("cc")
            break
          end
        end
        vim.notify("Rbuild failed, quickfix updated", vim.log.levels.ERROR)
      end)
    end,
  })

  if job_id <= 0 then
    vim.g.rbuild_job_id = nil
    vim.notify("Rbuild failed to start", vim.log.levels.ERROR)
    return
  end

  vim.g.rbuild_job_id = job_id
end, {
  nargs = "*",
  complete = "shellcmd",
  desc = "Run local rbuild with -f current relative file path and send output to quickfix",
})

vim.api.nvim_create_user_command("RbuildStop", function()
  local job_id = vim.g.rbuild_job_id
  if not job_id then
    vim.notify("Rbuild is not running", vim.log.levels.INFO)
    return
  end

  vim.fn.jobstop(job_id)
  vim.g.rbuild_stopping = true
  vim.g.rbuild_job_id = nil
  vim.fn.setqflist({}, "a", {
    items = { { text = "[Rbuild stopping...]" } },
  })
  vim.cmd("botright copen")
  vim.notify("Rbuild stopped", vim.log.levels.WARN)
end, {
  desc = "Stop the running Rbuild job",
})
