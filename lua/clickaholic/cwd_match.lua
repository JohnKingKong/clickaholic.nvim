-- lua/clickaholic/cwd_match.lua
local M = {}

-- A button with no cwd (nil or "") is global -- always visible. A button
-- with a cwd is only visible when the current directory is that path or a
-- subdirectory of it. Boundary-safe: a button scoped to "~/proj" must not
-- also match "~/proj-old" (a plain string-prefix check would).
function M.matches(button_cwd, cwd)
  if not button_cwd or button_cwd == "" then
    return true
  end
  return cwd == button_cwd or vim.startswith(cwd, button_cwd .. "/")
end

return M
