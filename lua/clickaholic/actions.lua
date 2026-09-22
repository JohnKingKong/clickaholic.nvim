-- lua/clickaholic/actions.lua
local M = {}

local last_output = nil

function M.get_last_output()
  return last_output
end

local function run_shell(action)
  vim.system({ "sh", "-c", action }, { text = true }, function(result)
    vim.schedule(function()
      local output = (result.stdout or "") .. (result.stderr or "")
      last_output = output
      local truncated = output:sub(1, 200)
      vim.notify(
        string.format("clickaholic: '%s' exited %d\n%s", action, result.code, truncated),
        result.code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
      )
    end)
  end)
end

function M.run(button)
  if button.action_type == "cmd" then
    local ok, err = pcall(vim.cmd, button.action)
    if not ok then
      vim.notify(
        string.format(
          "clickaholic: '%s' is not a valid Vim command (%s). "
            .. "If this is meant to run in a shell, edit the button and set Type to 'shell'.",
          button.action,
          tostring(err)
        ),
        vim.log.levels.ERROR
      )
    end
  elseif button.action_type == "shell" then
    run_shell(button.action)
  elseif button.action_type == "lua" then
    button.action()
  else
    vim.notify("clickaholic: unknown action_type '" .. tostring(button.action_type) .. "'", vim.log.levels.ERROR)
  end
end

return M
