-- tests/winbar_spec.lua
describe("clickaholic.winbar", function()
  local winbar

  before_each(function()
    package.loaded["clickaholic.winbar"] = nil
    package.loaded["clickaholic.actions"] = nil
    winbar = require("clickaholic.winbar")
  end)

  describe("render", function()
    it("builds one clickable segment per button with icon and label", function()
      local rendered = winbar.render({
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      })
      assert.is_true(rendered:find("🔭") ~= nil)
      assert.is_true(rendered:find("Search") ~= nil)
      assert.is_true(rendered:find("🧪") ~= nil)
      assert.is_true(rendered:find("Test") ~= nil)
      assert.is_true(rendered:find("%%1@") ~= nil)
      assert.is_true(rendered:find("%%2@") ~= nil)
    end)

    it("returns an empty string for no buttons", function()
      assert.are.equal("", winbar.render({}))
    end)

    it("renders an icon-only button without a stray double space", function()
      local rendered = winbar.render({
        { label = "", icon = "🚀", action_type = "cmd", action = ":X" },
      })
      assert.is_true(rendered:find("🚀 %%X") ~= nil, "expected a single space before %%X, got: " .. rendered)
    end)

    it("renders a label-only button without a stray leading space", function()
      local rendered = winbar.render({
        { label = "Deploy", icon = "", action_type = "cmd", action = ":X" },
      })
      assert.is_true(rendered:find("@ Deploy %%X") ~= nil, "expected a single space after @, got: " .. rendered)
    end)
  end)

  describe("click", function()
    it("runs the action for the button at the given id", function()
      local ran
      package.loaded["clickaholic.actions"] = { run = function(b)
        ran = b
      end }
      package.loaded["clickaholic.winbar"] = nil
      winbar = require("clickaholic.winbar")

      local buttons = {
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      }
      winbar.set_buttons(buttons)
      winbar.click(2)

      assert.are.equal("Test", ran.label)
    end)
  end)

  describe("apply", function()
    it("sets vim.o.winbar to the rendered string", function()
      local buttons = { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }
      winbar.apply(buttons)
      assert.are.equal(winbar.render(buttons), vim.o.winbar)
    end)
  end)
end)
