local M = {}

function M.render_list_lines(buttons)
  local lines = {}
  for _, button in ipairs(buttons) do
    local prefix = button.source == "config" and "[config] " or ""
    table.insert(lines, string.format("%s%s %s", prefix, button.icon, button.label))
  end
  return lines
end

function M.render_form_lines(button)
  button = button or {}
  return {
    "Label: " .. (button.label or ""),
    "Icon: " .. (button.icon or ""),
    "Type: " .. (button.action_type or "cmd"),
    "Action: " .. (button.action or ""),
  }
end

local function field_value(line, prefix)
  return line:sub(#prefix + 1)
end

function M.parse_form(lines)
  local label = field_value(lines[1], "Label: ")
  local icon = field_value(lines[2], "Icon: ")
  local action_type = field_value(lines[3], "Type: ")
  local action = field_value(lines[4], "Action: ")

  if label == "" then
    return nil, "Label cannot be empty"
  end
  if action_type ~= "cmd" and action_type ~= "shell" then
    return nil, "Type must be 'cmd' or 'shell'"
  end
  if action == "" then
    return nil, "Action cannot be empty"
  end

  return {
    label = label,
    icon = icon,
    action_type = action_type,
    action = action,
  }, nil
end

return M
