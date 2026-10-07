-- lua/clickaholic/tabufline.lua
-- NvChad's tabufline (lua/nvchad/tabufline/modules.lua) has its own custom
-- extension point: opts.modules (a table of plain no-arg functions returning
-- a statusline-format string) merged in alongside its built-ins, selected by
-- name in opts.order, then string-concatenated (unescaped) into the final
-- tabline -- the same unescaped-concatenation shape bufferline.nvim's
-- custom_areas uses, so the %<id>@Func@label%X click syntax survives intact
-- here too. tabufline's own built-in buttons happen to target Vimscript
-- functions (TbGoToBuf, etc.), but v:lua.require(...).func is an equally
-- valid click target in that same syntax -- confirmed by bufferline.lua
-- using exactly that.
--
-- Wire it into your own chadrc.lua:
--   M.ui = {
--     tabufline = {
--       modules = { clickaholic = require("clickaholic.tabufline").module },
--       order = { "treeOffset", "buffers", "tabs", "clickaholic", "btns" },
--     },
--   }
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
        "%%%d@v:lua.require'clickaholic.tabufline'.click@ %s %%X",
        i,
        icon_and_label(button.icon, button.label)
      )
    )
  end
  return table.concat(parts)
end

-- tabufline's modules table expects plain no-arg functions returning a
-- string directly (modules.lua: `table.insert(result, M[v]())`) -- not the
-- { { text = ... } } shape bufferline's custom_areas wants.
function M.module()
  local buttons = require("clickaholic").get_visible_buttons()
  M.set_buttons(buttons)
  return M.render(buttons)
end

-- tabufline re-evaluates its tabline on its own redraw cycle, but that's
-- driven by buffer/window events, not button edits -- :redrawtabline forces
-- an immediate re-evaluation so a button added/edited/deleted via
-- :Clickaholic shows up right away.
function M.apply(buttons)
  M.set_buttons(buttons)
  pcall(vim.cmd, "redrawtabline")
end

return M
