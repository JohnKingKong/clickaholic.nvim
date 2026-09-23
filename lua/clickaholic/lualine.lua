local M = {}

-- Icon and label are both optional (at least one is required by
-- manage_ui.parse_form), so joining them with a fixed space would leave a
-- stray leading or trailing space when only one is set.
local function icon_and_label(icon, label)
  if icon ~= "" and label ~= "" then
    return icon .. " " .. label
  end
  return icon .. label
end

-- Buttons render as lualine components (https://github.com/nvim-lualine/lualine.nvim),
-- not a floating window or a raw vim.o.winbar/statusline/tabline assignment.
-- Three earlier approaches were tried and abandoned in turn:
--   1. vim.o.winbar on a floating window, switching tabs to create it: a
--      confirmed native SIGSEGV crash (buf_copy_options via enter_tabpage)
--      when reviewing a change in a different fireplace.
--   2. The same floating window built via nvim_win_call instead (never
--      switching tabs): the crash was gone, but winbar on a floating window
--      still reserves a layout row that participates in Neovim's window-room
--      accounting, so recreating it on every TabEnter (unavoidable, floats
--      belong to the tab they're created in) printed "E36: Not enough room"
--      on essentially every tab switch.
--   3. Neovim's global statusline (laststatus = 3), set once, no per-tab
--      management at all: genuinely zero errors of any kind, but LazyVim
--      already bundles lualine.nvim, which owns and continuously
--      re-renders vim.o.statusline itself -- clickaholic's one-time
--      assignment got silently overwritten by lualine's next redraw.
-- lualine.nvim has first-class support for clickable components
-- (`options.on_click`, using the identical %<id>@Func@label%X mechanism
-- clickaholic built by hand) -- becoming a component sidesteps the
-- ownership conflict entirely instead of fighting it, and touches no
-- tab/window machinery whatsoever, so none of the above failure modes can
-- apply here.
--
-- lualine's on_click is per-COMPONENT, not per-segment within one
-- component's rendered string (nested click regions aren't a thing in
-- Neovim's statusline format), so this returns one component per button
-- rather than a single component containing all of them.
function M.components()
  local components = {}
  for _, button in ipairs(require("clickaholic").get_visible_buttons()) do
    table.insert(components, {
      function()
        return icon_and_label(button.icon, button.label)
      end,
      on_click = function()
        require("clickaholic.actions").run(button)
      end,
    })
  end
  return components
end

-- The actual lualine config (sections, theme, everything else) belongs to
-- the user, not clickaholic -- integration lives in their own lualine.nvim
-- plugin spec, which merges M.components() in and re-calls
-- require('lualine').setup(...) whenever this fires. Buttons don't need
-- threading through here: M.components() always re-reads the current list
-- from clickaholic itself when the listener next calls it.
function M.apply(_buttons)
  vim.api.nvim_exec_autocmds("User", { pattern = "ClickaholicButtonsChanged" })
end

return M
