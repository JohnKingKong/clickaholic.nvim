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
        "%%%d@v:lua.require'clickaholic.statusbar'.click@ %s %%X",
        i,
        icon_and_label(button.icon, button.label)
      )
    )
  end
  return table.concat(parts)
end

-- The button bar renders into Neovim's GLOBAL statusline (`laststatus = 3`)
-- rather than a per-window winbar or a per-tab floating window. This is a
-- genuinely single, global option -- Neovim keeps it correctly displayed
-- across every window and tab switch entirely on its own, with no
-- per-tab bookkeeping or recreate-on-TabEnter logic needed here at all.
--
-- Two earlier approaches (a floating window using vim.o.winbar, both with
-- and without nvim_set_current_tabpage) were abandoned: setting `winbar` on
-- a floating window reserves a layout row that participates in Neovim's
-- window-room accounting, and recreating that window on every TabEnter
-- (unavoidable -- floats belong to the tab they're created in) triggered
-- "E36: Not enough room" messages on essentially every tab switch, even
-- with the tab-switching itself made safe. Confirmed via the same stress
-- test (rapid tabnew/tcd/tabprevious/tabnext cycling) that this global
-- statusline produces zero such messages, since there's no per-tab window
-- to recreate in the first place.
--
-- The one real tradeoff: this renders at the bottom of the screen (Vim's
-- statusline convention), not the top.
function M.apply(buttons)
  M.set_buttons(buttons)
  vim.o.laststatus = 3
  vim.o.statusline = M.render(buttons)
end

return M
