-- tests/tabufline_spec.lua
describe("clickaholic.tabufline", function()
  local tabufline

  before_each(function()
    package.loaded["clickaholic.tabufline"] = nil
    package.loaded["clickaholic.actions"] = nil
    package.loaded["clickaholic"] = nil
    tabufline = require("clickaholic.tabufline")
  end)

  describe("render", function()
    it("builds one clickable segment per button with icon and label", function()
      local rendered = tabufline.render({
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
      assert.are.equal("", tabufline.render({}))
    end)

    it("renders an icon-only button without a stray double space", function()
      local rendered = tabufline.render({
        { label = "", icon = "🚀", action_type = "cmd", action = ":X" },
      })
      assert.is_true(rendered:find("🚀 %%X") ~= nil, "expected a single space before %%X, got: " .. rendered)
    end)

    it("renders a label-only button without a stray leading space", function()
      local rendered = tabufline.render({
        { label = "Deploy", icon = "", action_type = "cmd", action = ":X" },
      })
      assert.is_true(rendered:find("@ Deploy %%X") ~= nil, "expected a single space after @, got: " .. rendered)
    end)
  end)

  describe("click", function()
    it("runs the action for the button at the given id", function()
      local ran
      package.loaded["clickaholic.actions"] = {
        run = function(b)
          ran = b
        end,
      }
      package.loaded["clickaholic.tabufline"] = nil
      tabufline = require("clickaholic.tabufline")

      local buttons = {
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      }
      tabufline.set_buttons(buttons)
      tabufline.click(2)

      assert.are.equal("Test", ran.label)
    end)
  end)

  describe("module", function()
    it("returns the full rendered button string directly (no wrapper table)", function()
      package.loaded["clickaholic"] = {
        get_visible_buttons = function()
          return { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }
        end,
      }
      local result = tabufline.module()
      assert.are.equal(
        tabufline.render({ { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }),
        result
      )
    end)

    it("updates current_buttons so click() dispatches correctly after being called", function()
      local ran
      package.loaded["clickaholic.actions"] = {
        run = function(b)
          ran = b
        end,
      }
      package.loaded["clickaholic.tabufline"] = nil
      tabufline = require("clickaholic.tabufline")
      package.loaded["clickaholic"] = {
        get_visible_buttons = function()
          return {
            { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
            { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
          }
        end,
      }

      tabufline.module()
      tabufline.click(2)

      assert.are.equal("Test", ran.label)
    end)
  end)

  describe("apply", function()
    it("forces a tabline redraw without throwing", function()
      local ok = pcall(tabufline.apply, {})
      assert.is_true(ok)
    end)
  end)
end)
