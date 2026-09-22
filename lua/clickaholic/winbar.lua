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

-- Icon and label are both optional (at least one is required by
-- manage_ui.parse_form), so joining them with a fixed space would leave a
-- stray leading or trailing space when only one is set.
local function icon_and_label(icon, label)
  if icon ~= "" and label ~= "" then
    return icon .. " " .. label
  end
  return icon .. label
end

function M.render(buttons)
  if #buttons == 0 then
    return ""
  end
  local parts = { "%<" }
  for i, button in ipairs(buttons) do
    table.insert(
      parts,
      string.format(
        "%%%d@v:lua.require'clickaholic.winbar'.click@ %s %%X",
        i,
        icon_and_label(button.icon, button.label)
      )
    )
  end
  return table.concat(parts)
end

function M.apply(buttons)
  M.set_buttons(buttons)
  vim.o.winbar = M.render(buttons)
end

return M
