local M = {}

local current_buttons = {}

function M.set_buttons(buttons)
  current_buttons = buttons
end

function M.click(id)
  local button = current_buttons[id]
  if button then
    require("clickaholic.actions").run(button)
  end
end

function M.render(buttons)
  if #buttons == 0 then
    return ""
  end
  local parts = { "%<" }
  for i, button in ipairs(buttons) do
    table.insert(
      parts,
      string.format("%%%d@v:lua.require'clickaholic.winbar'.click@ %s %s %%X", i, button.icon, button.label)
    )
  end
  return table.concat(parts)
end

function M.apply(buttons)
  M.set_buttons(buttons)
  vim.o.winbar = M.render(buttons)
end

return M
