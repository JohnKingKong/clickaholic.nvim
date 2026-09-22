-- tests/tabline_spec.lua
describe("clickaholic.tabline", function()
  local tabline

  before_each(function()
    package.loaded["clickaholic.tabline"] = nil
    package.loaded["clickaholic.actions"] = nil
    package.loaded["clickaholic"] = nil
    tabline = require("clickaholic.tabline")
  end)

  describe("render", function()
    it("builds one clickable segment per button with icon and label", function()
      local rendered = tabline.render({
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
      assert.are.equal("", tabline.render({}))
    end)

    it("renders an icon-only button without a stray double space", function()
      local rendered = tabline.render({
        { label = "", icon = "🚀", action_type = "cmd", action = ":X" },
      })
      assert.is_true(rendered:find("🚀 %%X") ~= nil, "expected a single space before %%X, got: " .. rendered)
    end)

    it("renders a label-only button without a stray leading space", function()
      local rendered = tabline.render({
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
      package.loaded["clickaholic.tabline"] = nil
      tabline = require("clickaholic.tabline")

      local buttons = {
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      }
      tabline.set_buttons(buttons)
      tabline.click(2)

      assert.are.equal("Test", ran.label)
    end)
  end)

  describe("custom_area", function()
    it("returns a single item whose text is the full rendered button string", function()
      package.loaded["clickaholic"] = {
        get_buttons = function()
          return { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }
        end,
      }
      local area = tabline.custom_area()
      assert.are.equal(1, #area)
      assert.are.equal(
        tabline.render({ { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" } }),
        area[1].text
      )
    end)

    it("updates current_buttons so click() dispatches correctly after being called", function()
      local ran
      package.loaded["clickaholic.actions"] = {
        run = function(b)
          ran = b
        end,
      }
      package.loaded["clickaholic.tabline"] = nil
      tabline = require("clickaholic.tabline")
      package.loaded["clickaholic"] = {
        get_buttons = function()
          return {
            { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
            { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
          }
        end,
      }

      tabline.custom_area()
      tabline.click(2)

      assert.are.equal("Test", ran.label)
    end)
  end)

  describe("apply", function()
    it("forces a tabline redraw without throwing", function()
      local ok = pcall(tabline.apply, {})
      assert.is_true(ok)
    end)
  end)
end)
