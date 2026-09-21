describe("clickaholic plugin entrypoint", function()
  before_each(function()
    vim.g.loaded_clickaholic = nil
    pcall(vim.api.nvim_del_user_command, "Clickaholic")
    pcall(vim.api.nvim_del_user_command, "ClickaholicOutput")
    dofile("plugin/clickaholic.lua")
  end)

  it("registers :Clickaholic and :ClickaholicOutput", function()
    local commands = vim.api.nvim_get_commands({})
    assert.is_not_nil(commands["Clickaholic"])
    assert.is_not_nil(commands["ClickaholicOutput"])
  end)

  it("does not re-register on a second load", function()
    local ok = pcall(dofile, "plugin/clickaholic.lua")
    assert.is_true(ok)
  end)
end)
