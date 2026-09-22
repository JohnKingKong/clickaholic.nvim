-- tests/actions_spec.lua
describe("clickaholic.actions", function()
  local actions

  before_each(function()
    package.loaded["clickaholic.actions"] = nil
    actions = require("clickaholic.actions")
  end)

  describe("cmd action", function()
    it("runs the command via vim.cmd", function()
      local captured
      local original_cmd = vim.cmd
      vim.cmd = function(c)
        captured = c
      end
      actions.run({ action_type = "cmd", action = ":echo 'hi'" })
      vim.cmd = original_cmd
      assert.are.equal(":echo 'hi'", captured)
    end)

    it("notifies a friendly error instead of raising when the command is invalid", function()
      local notified
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        notified = { msg = msg, level = level }
      end

      local ok = pcall(actions.run, { action_type = "cmd", action = "pnpm run start" })

      vim.notify = original_notify

      assert.is_true(ok, "actions.run must never raise, even on an invalid Ex command")
      assert.is_not_nil(notified)
      assert.are.equal(vim.log.levels.ERROR, notified.level)
      assert.is_true(notified.msg:find("pnpm run start") ~= nil, "message must name the failing command")
      assert.is_true(
        notified.msg:find("shell") ~= nil,
        "message must hint that action_type might need to be 'shell' instead"
      )
    end)
  end)

  describe("lua action", function()
    it("calls the function", function()
      local called = false
      actions.run({
        action_type = "lua",
        action = function()
          called = true
        end,
      })
      assert.is_true(called)
    end)
  end)

  describe("shell action", function()
    it("runs zsh's own action through -c after silently sourcing .zshrc", function()
      -- A bare "sh -c" subprocess never sources .zshrc/.bashrc, so version
      -- managers (nvm, pyenv, ...) set up there are invisible to it. An
      -- interactive shell (-i) would source it, but also inherits
      -- interactive-only side effects (prompt themes, job control) that
      -- print noise or fail outright without a real TTY -- explicitly
      -- sourcing the rc file inside a plain "-c" shell avoids that.
      local captured_cmd
      local original_system = vim.system
      local original_shell = vim.env.SHELL
      vim.env.SHELL = "/bin/zsh"
      vim.system = function(cmd, _opts, callback)
        captured_cmd = cmd
        callback({ code = 0, stdout = "", stderr = "" })
      end

      actions.run({ action_type = "shell", action = "echo hi" })
      -- run_shell's own notify is deferred via vim.schedule even though
      -- this stub's callback fires synchronously -- flush it now so it
      -- doesn't fire later, during a subsequent test's vim.wait() polling.
      vim.wait(20)

      vim.system = original_system
      vim.env.SHELL = original_shell

      assert.are.same({ "/bin/zsh", "-c", "source ~/.zshrc >/dev/null 2>&1; echo hi" }, captured_cmd)
    end)

    it("runs bash's action through -c after silently sourcing .bashrc", function()
      local captured_cmd
      local original_system = vim.system
      local original_shell = vim.env.SHELL
      vim.env.SHELL = "/bin/bash"
      vim.system = function(cmd, _opts, callback)
        captured_cmd = cmd
        callback({ code = 0, stdout = "", stderr = "" })
      end

      actions.run({ action_type = "shell", action = "echo hi" })
      -- run_shell's own notify is deferred via vim.schedule even though
      -- this stub's callback fires synchronously -- flush it now so it
      -- doesn't fire later, during a subsequent test's vim.wait() polling.
      vim.wait(20)

      vim.system = original_system
      vim.env.SHELL = original_shell

      assert.are.same({ "/bin/bash", "-c", "source ~/.bashrc >/dev/null 2>&1; echo hi" }, captured_cmd)
    end)

    it("falls back to /bin/sh with no rc file when $SHELL is unset", function()
      local captured_cmd
      local original_system = vim.system
      local original_shell = vim.env.SHELL
      vim.env.SHELL = nil
      vim.system = function(cmd, _opts, callback)
        captured_cmd = cmd
        callback({ code = 0, stdout = "", stderr = "" })
      end

      actions.run({ action_type = "shell", action = "echo hi" })
      -- run_shell's own notify is deferred via vim.schedule even though
      -- this stub's callback fires synchronously -- flush it now so it
      -- doesn't fire later, during a subsequent test's vim.wait() polling.
      vim.wait(20)

      vim.system = original_system
      vim.env.SHELL = original_shell

      assert.are.same({ "/bin/sh", "-c", "echo hi" }, captured_cmd)
    end)

    it("runs the command, notifies a summary, and stores full output", function()
      local notified
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        notified = { msg = msg, level = level }
      end

      actions.run({ action_type = "shell", action = "echo hello-clickaholic" })
      vim.wait(2000, function()
        return notified ~= nil
      end, 20)

      vim.notify = original_notify

      assert.is_not_nil(notified)
      assert.is_true(notified.msg:find("hello%-clickaholic") ~= nil)
      assert.is_true(actions.get_last_output():find("hello%-clickaholic") ~= nil)
    end)
  end)
end)
