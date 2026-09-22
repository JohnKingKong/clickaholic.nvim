-- lua/clickaholic/actions.lua
local M = {}

local last_output = nil

function M.get_last_output()
  return last_output
end

-- A plain "sh -c" subprocess inherits Neovim's own process environment,
-- which -- especially for a GUI-launched frontend like Neovide, started
-- from Finder/Dock rather than a terminal -- may not include PATH entries
-- that only get set up by shell startup files (nvm, pyenv, etc.). Those
-- live in .zshrc/.bashrc, which zsh/bash only source for INTERACTIVE
-- shells -- but actually spawning an interactive shell (-i) pulls in
-- interactive-only side effects too (prompt themes, job control), which
-- print noise or fail outright without a real TTY (confirmed: a
-- powerlevel10k+gitstatus setup fails to init and dumps an error under
-- -i here). Explicitly sourcing the rc file inside a plain, non-interactive
-- "-c" shell gets the same PATH without that noise.
local RC_FILE_BY_SHELL = { zsh = "~/.zshrc", bash = "~/.bashrc" }

local function run_shell(action)
  local shell = vim.env.SHELL or "/bin/sh"
  local rc_file = RC_FILE_BY_SHELL[vim.fn.fnamemodify(shell, ":t")]
  local full_action = rc_file and ("source " .. rc_file .. " >/dev/null 2>&1; " .. action) or action
  vim.system({ shell, "-c", full_action }, { text = true }, function(result)
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
