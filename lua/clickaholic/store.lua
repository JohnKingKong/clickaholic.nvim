-- lua/clickaholic/store.lua
local M = {}

function M.default_path()
  return vim.fn.stdpath("data") .. "/clickaholic.json"
end

function M.load(path)
  if vim.fn.filereadable(path) ~= 1 then
    return {}
  end
  local content = table.concat(vim.fn.readfile(path), "\n")
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    vim.notify("clickaholic: could not parse " .. path .. ", ignoring", vim.log.levels.WARN)
    return {}
  end
  for _, button in ipairs(decoded) do
    button.source = "stored"
  end
  return decoded
end

function M.save(path, buttons)
  local to_write = {}
  for _, button in ipairs(buttons) do
    table.insert(to_write, {
      label = button.label,
      icon = button.icon,
      action_type = button.action_type,
      action = button.action,
    })
  end
  vim.fn.writefile({ vim.json.encode(to_write) }, path)
end

function M.add(path, button)
  local buttons = M.load(path)
  button.source = "stored"
  table.insert(buttons, button)
  M.save(path, buttons)
  return buttons
end

function M.update(path, index, button)
  local buttons = M.load(path)
  button.source = "stored"
  buttons[index] = button
  M.save(path, buttons)
  return buttons
end

function M.remove(path, index)
  local buttons = M.load(path)
  table.remove(buttons, index)
  M.save(path, buttons)
  return buttons
end

function M.move(path, index, direction)
  local buttons = M.load(path)
  local target = direction == "up" and (index - 1) or (index + 1)
  if target >= 1 and target <= #buttons then
    buttons[index], buttons[target] = buttons[target], buttons[index]
    M.save(path, buttons)
  end
  return buttons
end

return M
