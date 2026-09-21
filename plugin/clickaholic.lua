if vim.g.loaded_clickaholic then
  return
end
vim.g.loaded_clickaholic = true

vim.api.nvim_create_user_command("Clickaholic", function()
  require("clickaholic.manage_ui").open()
end, { desc = "Open the clickaholic button manager" })

vim.api.nvim_create_user_command("ClickaholicOutput", function()
  local output = require("clickaholic.actions").get_last_output()
  if not output then
    vim.notify("clickaholic: no shell output yet", vim.log.levels.INFO)
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, "\n"))
  vim.cmd("tabnew")
  vim.api.nvim_win_set_buf(0, buf)
end, { desc = "Show the last clickaholic shell action's full output" })
