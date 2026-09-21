-- lua/clickaholic/icon_picker.lua
local M = {}

M.ICONS = {
  { icon = "📁", name = "folder" },
  { icon = "🚀", name = "rocket" },
  { icon = "🔧", name = "wrench" },
  { icon = "✅", name = "check" },
  { icon = "❌", name = "cross" },
  { icon = "🔥", name = "fire" },
  { icon = "⭐", name = "star" },
  { icon = "⚙️", name = "gear" },
  { icon = "🐛", name = "bug" },
  { icon = "🧪", name = "test" },
  { icon = "🌳", name = "tree" },
  { icon = "🔍", name = "search" },
  { icon = "🌿", name = "branch" },
  { icon = "📦", name = "package" },
  { icon = "💻", name = "terminal" },
  { icon = "📖", name = "book" },
  { icon = "🔗", name = "link" },
  { icon = "⚡", name = "lightning" },
  { icon = "🔔", name = "bell" },
  { icon = "🔒", name = "lock" },
  { icon = "🔑", name = "key" },
  { icon = "🎨", name = "paint" },
  { icon = "📊", name = "chart" },
  { icon = "⏰", name = "clock" },
  { icon = "⚠️", name = "warning" },
  { icon = "ℹ️", name = "info" },
  { icon = "💾", name = "save" },
  { icon = "🗑️", name = "trash" },
  { icon = "🔄", name = "refresh" },
  { icon = "▶️", name = "play" },
  { icon = "🏠", name = "home" },
  { icon = "🌐", name = "globe" },
  { icon = "📧", name = "mail" },
  { icon = "📅", name = "calendar" },
  { icon = "📌", name = "pin" },
  { icon = "🏷️", name = "tag" },
  { icon = "🚩", name = "flag" },
  { icon = "✨", name = "sparkles" },
  { icon = "🔨", name = "hammer" },
  { icon = "💡", name = "idea" },
  { icon = "👍", name = "thumbsup" },
  { icon = "🎉", name = "party" },
  { icon = "🤖", name = "robot" },
  { icon = "👀", name = "eyes" },
  { icon = "📎", name = "clip" },
  { icon = "🧭", name = "compass" },
}

function M.render_lines()
  local lines = {}
  for _, entry in ipairs(M.ICONS) do
    table.insert(lines, entry.icon .. "  " .. entry.name)
  end
  return lines
end

function M.parse_line(line)
  return line:match("^(.-)  ")
end

-- Opens a floating window listing the curated icons. Native `/` search,
-- `j`/`k`, `gg`/`G` browse the list -- no custom filtering code needed.
-- `<CR>` calls on_select(icon) with the icon under the cursor and closes the
-- window; `<Esc>`/`q` closes without calling on_select. Returns the window id.
function M.open(on_select)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, M.render_lines())
  vim.bo[buf].modifiable = false

  local width = 24
  local height = math.min(#M.ICONS, math.floor(vim.o.lines * 0.6))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    border = "rounded",
    title = " pick an icon (/ to search) ",
  })

  local opts = { buffer = buf, nowait = true, silent = true }

  vim.keymap.set("n", "<CR>", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    local icon = M.parse_line(line)
    pcall(vim.api.nvim_win_close, win, true)
    if icon then
      on_select(icon)
    end
  end, opts)

  for _, lhs in ipairs({ "<Esc>", "q" }) do
    vim.keymap.set("n", lhs, function()
      pcall(vim.api.nvim_win_close, win, true)
    end, opts)
  end

  return win
end

return M
