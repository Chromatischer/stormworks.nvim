-- Simple logger and print capture
local logger = {
  lines = {},
  max_lines = 1000,
  _fh = nil,          -- file handle for optional on-disk logging
  _file_path = nil,   -- path to active log file
}

local function append_line(text)
  table.insert(logger.lines, text)
  if #logger.lines > logger.max_lines then
    table.remove(logger.lines, 1)
  end
  -- Write-through to file if enabled
  if logger._fh then
    if type(text) ~= 'string' then text = tostring(text) end
    if not text:match("\n$") then text = text .. "\n" end
    logger._fh:write(text)
    logger._fh:flush()
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

-- Enable writing log lines to a file that can be tailed from a terminal
-- opts = { truncate = boolean|nil } -- when true, clears the file first (default: false)
function logger.enable_file(path, opts)
  opts = opts or {}
  -- Close existing handle if switching paths
  if logger._fh then
    pcall(function() logger._fh:flush(); logger._fh:close() end)
    logger._fh = nil
  end
  local mode = (opts.truncate and 'w') or 'a'
  local fh, err = io.open(path, mode)
  if not fh then
    -- Try to create parent directory then retry
    local dir = tostring(path):match("^(.*)[/\\][^/\\]+$")
    if dir and #dir > 0 then
      local is_windows = package.config and package.config:sub(1,1) == '\\'
      local cmd
      if is_windows then
        cmd = string.format('mkdir "%s"', dir)
      else
        cmd = string.format('mkdir -p "%s"', dir)
      end
      pcall(function() os.execute(cmd) end)
      fh, err = io.open(path, mode)
    end
    if not fh then
      return false, err
    end
  end
  logger._fh = fh
  logger._file_path = path
  -- Write a session separator when appending
  if mode == 'a' then
    fh:write("\n----- LOG SESSION START -----\n")
  end
  fh:flush()
  return true
end

function logger.disable_file()
  if logger._fh then
    pcall(function() logger._fh:flush(); logger._fh:close() end)
    logger._fh = nil
  end
end

function logger.get_file_path()
  return logger._file_path
end

return logger
