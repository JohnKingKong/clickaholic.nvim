-- tests/lualine_spec.lua
describe("clickaholic.lualine", function()
  local lualine_integration

  local function stub_clickaholic(buttons)
    package.loaded["clickaholic"] = {
      get_visible_buttons = function()
        return buttons
      end,
    }
  end

  before_each(function()
    package.loaded["clickaholic.lualine"] = nil
    package.loaded["clickaholic.actions"] = nil
    package.loaded["clickaholic"] = nil
    lualine_integration = require("clickaholic.lualine")
  end)

  describe("components", function()
    it("returns one component per button", function()
      stub_clickaholic({
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      })
      local components = lualine_integration.components()
      assert.are.equal(2, #components)
    end)

    it("each component's first element renders icon and label", function()
      stub_clickaholic({
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
      })
      local components = lualine_integration.components()
      assert.are.equal("🔭 Search", components[1][1]())
    end)

    it("renders an icon-only button without a stray trailing space", function()
      stub_clickaholic({
        { label = "", icon = "🚀", action_type = "cmd", action = ":X" },
      })
      local components = lualine_integration.components()
      assert.are.equal("🚀", components[1][1]())
    end)

    it("renders a label-only button without a stray leading space", function()
      stub_clickaholic({
        { label = "Deploy", icon = "", action_type = "cmd", action = ":X" },
      })
      local components = lualine_integration.components()
      assert.are.equal("Deploy", components[1][1]())
    end)

    it("each component's on_click runs that button's own action", function()
      local ran
      package.loaded["clickaholic.actions"] = {
        run = function(b)
          ran = b
        end,
      }
      stub_clickaholic({
        { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope" },
        { label = "Test", icon = "🧪", action_type = "shell", action = "npm test" },
      })
      local components = lualine_integration.components()

      components[2].on_click()

      assert.are.equal("Test", ran.label)
    end)

    it("returns an empty list when there are no buttons", function()
      stub_clickaholic({})
      assert.are.same({}, lualine_integration.components())
    end)

    it("re-reads the current button list on every call, not a stale snapshot", function()
      local buttons = { { label = "One", icon = "1", action_type = "cmd", action = ":X" } }
      stub_clickaholic(buttons)
      assert.are.equal(1, #lualine_integration.components())

      table.insert(buttons, { label = "Two", icon = "2", action_type = "cmd", action = ":Y" })
      assert.are.equal(2, #lualine_integration.components())
    end)
  end)

  describe("apply", function()
    it("fires a ClickaholicButtonsChanged User autocmd", function()
      local fired = false
      local augroup = vim.api.nvim_create_augroup("lualine_spec_test", { clear = true })
      vim.api.nvim_create_autocmd("User", {
        group = augroup,
        pattern = "ClickaholicButtonsChanged",
        callback = function()
          fired = true
        end,
      })

      lualine_integration.apply({})

      vim.api.nvim_del_augroup_by_id(augroup)
      assert.is_true(fired)
    end)
  end)
end)
