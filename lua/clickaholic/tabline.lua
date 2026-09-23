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
  local parts = {}
  for i, button in ipairs(buttons) do
    table.insert(
      parts,
      string.format(
        "%%%d@v:lua.require'clickaholic.tabline'.click@ %s %%X",
        i,
        icon_and_label(button.icon, button.label)
      )
    )
  end
  return table.concat(parts)
end

-- Four earlier approaches to a single, never-duplicated, top-of-editor bar
-- were tried and abandoned in turn:
--   1-2. vim.o.winbar on a floating window (with and without
--        nvim_set_current_tabpage): a confirmed native crash, then
--        confirmed-safe-but-noisy "E36: Not enough room" on nearly every
--        tab switch -- winbar on a float reserves a layout row that
--        participates in Neovim's window-room accounting.
--   3. Neovim's global statusline (laststatus = 3): zero errors, genuinely
--      single-instance, but bottom-of-editor, and LazyVim already bundles
--      lualine.nvim which owns and continuously re-renders vim.o.statusline.
--   4. lualine.nvim components (options.on_click): worked, but still
--      bottom-of-editor -- lualine renders the statusline, not the tabline.
-- vim.o.tabline is the one surface that's genuinely single (one row for the
-- whole editor, not per-window or per-tab) AND top-of-editor -- but
-- bufferline.nvim already owns it for buffer tabs. bufferline.nvim has an
-- OFFICIAL, DOCUMENTED extension point for exactly this
-- (options.custom_areas.left/right, bufferline/custom_area.lua): a function
-- returning { { text = "..." } } items that get string-concatenated
-- (unescaped) into the final tabline, so the %<id>@Func@label%X click
-- syntax survives intact. This is bufferline choosing to share the surface
-- on purpose, not clickaholic fighting another plugin for ownership the way
-- every prior attempt did.
function M.custom_area()
  local buttons = require("clickaholic").get_visible_buttons()
  M.set_buttons(buttons)
  return { { text = M.render(buttons) } }
end

-- bufferline re-evaluates its tabline (and so custom_area()) on its own
-- redraw cycle, but that's driven by buffer/window events, not button
-- edits -- :redrawtabline forces an immediate re-evaluation so a button
-- added/edited/deleted via :Clickaholic shows up right away rather than
-- waiting for some unrelated redraw to happen to trigger it.
function M.apply(buttons)
  M.set_buttons(buttons)
  pcall(vim.cmd, "redrawtabline")
end

return M
