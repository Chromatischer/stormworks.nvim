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
end

function logger.printf(fmt, ...)
  append_line(string.format(fmt, ...))
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
