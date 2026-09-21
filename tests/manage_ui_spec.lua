-- tests/manage_ui_spec.lua
describe("clickaholic.manage_ui", function()
  local manage_ui

  before_each(function()
    package.loaded["clickaholic.manage_ui"] = nil
    manage_ui = require("clickaholic.manage_ui")
  end)

  describe("render_list_lines", function()
    it("tags config buttons and lists stored ones plainly", function()
      local lines = manage_ui.render_list_lines({
        { label = "Search", icon = "🔭", source = "config" },
        { label = "Test", icon = "🧪", source = "stored" },
      })
      assert.are.equal(2, #lines)
      assert.is_true(lines[1]:find("%[config%]") ~= nil)
      assert.is_true(lines[1]:find("Search") ~= nil)
      assert.is_nil(lines[2]:find("%[config%]"))
      assert.is_true(lines[2]:find("Test") ~= nil)
    end)
  end)

  describe("render_form_lines", function()
    it("returns empty fields for add mode (nil button)", function()
      local lines = manage_ui.render_form_lines(nil)
      assert.are.same({
        "Label: ",
        "Icon: ",
        "Type: cmd",
        "Action: ",
      }, lines)
    end)

    it("pre-fills fields for edit mode", function()
      local lines = manage_ui.render_form_lines({
        label = "Test",
        icon = "🧪",
        action_type = "shell",
        action = "npm test",
      })
      assert.are.same({
        "Label: Test",
        "Icon: 🧪",
        "Type: shell",
        "Action: npm test",
      }, lines)
    end)
  end)

  describe("parse_form", function()
    it("parses valid form lines into a button", function()
      local button, err = manage_ui.parse_form({
        "Label: Test",
        "Icon: 🧪",
        "Type: shell",
        "Action: npm test",
      })
      assert.is_nil(err)
      assert.are.same({
        label = "Test",
        icon = "🧪",
        action_type = "shell",
        action = "npm test",
      }, button)
    end)

    it("rejects an empty label", function()
      local button, err = manage_ui.parse_form({
        "Label: ",
        "Icon: 🧪",
        "Type: shell",
        "Action: npm test",
      })
      assert.is_nil(button)
      assert.is_true(err:find("[Ll]abel") ~= nil)
    end)

    it("rejects an empty action", function()
      local button, err = manage_ui.parse_form({
        "Label: Test",
        "Icon: 🧪",
        "Type: shell",
        "Action: ",
      })
      assert.is_nil(button)
      assert.is_true(err:find("[Aa]ction") ~= nil)
    end)

    it("rejects an invalid action type", function()
      local button, err = manage_ui.parse_form({
        "Label: Test",
        "Icon: 🧪",
        "Type: lua",
        "Action: npm test",
      })
      assert.is_nil(button)
      assert.is_true(err:find("[Tt]ype") ~= nil)
    end)
  end)
end)

describe("clickaholic.manage_ui.open", function()
  local manage_ui
  local path

  before_each(function()
    package.loaded["clickaholic.manage_ui"] = nil
    package.loaded["clickaholic.store"] = nil
    package.loaded["clickaholic.winbar"] = nil
    package.loaded["clickaholic"] = nil

    path = vim.fn.tempname() .. ".json"
    package.loaded["clickaholic"] = {
      get_buttons = function()
        return { { label = "Search", icon = "🔭", action_type = "cmd", action = ":Telescope", source = "config" } }
      end,
    }

    manage_ui = require("clickaholic.manage_ui")
  end)

  after_each(function()
    vim.fn.delete(path)
    pcall(vim.api.nvim_win_close, manage_ui._last_win, true)
  end)

  it("opens a floating window showing the button list", function()
    manage_ui.open()
    assert.is_true(vim.api.nvim_win_is_valid(manage_ui._last_win))
    local buf = vim.api.nvim_win_get_buf(manage_ui._last_win)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local found = false
    for _, line in ipairs(lines) do
      if line:find("Search") then
        found = true
      end
    end
    assert.is_true(found)
  end)
end)
