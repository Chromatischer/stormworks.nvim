-- Simple logger and print capture
local logger = {
  lines = {},
  max_lines = 1000,
}

local function append_line(text)
  table.insert(logger.lines, text)
  if #logger.lines > logger.max_lines then
    table.remove(logger.lines, 1)
  end
end

function logger.append(text)
  append_line(text)
  -- Echo to console as well, so crashes during attach or simulator phases are visible in terminal
  if type(text) ~= 'string' then text = tostring(text) end
  if text and #text > 0 then
    -- use original print to avoid recursion with print-capture
    if orig_print then orig_print(text) end
  end
end

function logger.printf(fmt, ...)
  local line = string.format(fmt, ...)
  append_line(line)
  if orig_print then orig_print(line) end
end

function logger.getLines(max)
  if not max or max >= #logger.lines then return logger.lines end
  local out = {}
  for i = #logger.lines - max + 1, #logger.lines do
    table.insert(out, logger.lines[i])
  end
  return out
end

-- Override print to capture console output
local orig_print = print
function logger.install_print_capture()
  print = function(...)
    local parts = {}
    for i=1,select('#', ...) do
      parts[i] = tostring(select(i, ...))
    end
    local line = table.concat(parts, '\t')
    append_line(line)
    orig_print(line)
  end
end

return logger
