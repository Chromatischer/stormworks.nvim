-- Mock Neovim API for unit testing
local MockVim = {}

MockVim._state = {
  cwd = "/test/project",
  files = {},
  commands = {},
  autocmds = {},
  lsp_clients = {},
}

MockVim.fn = {
  getcwd = function() return MockVim._state.cwd end,

  fnamemodify = function(path, mod)
    if mod == ":p" then
      if path:sub(1, 1) == "/" then
        return path
      else
        return MockVim._state.cwd .. "/" .. path
      end
    end
    if mod == ":h" then return path:match("^(.*)/[^/]+$") or path end
    if mod == ":t" then return path:match("([^/]+)$") or path end
    if mod == ":e" then return path:match("%.([^./]+)$") or "" end
    if mod == ":r" then return path:match("^(.*)%.[^./]+$") or path end
    return path
  end,

  expand = function(path)
    path = path:gsub("~", os.getenv("HOME") or "/home/user")
    path = path:gsub("<cwd>", MockVim._state.cwd)
    return path
  end,

  isdirectory = function(path)
    -- First check mock state
    local info = MockVim._state.files[path]
    if info then
      return (info.type == "directory") and 1 or 0
    end
    -- Fall back to actual filesystem check for test temp directories
    -- Use io.popen to check if it's a directory since os.execute return values vary
    local handle = io.popen('test -d "' .. path .. '" && echo "yes" || echo "no"')
    if handle then
      local result = handle:read("*l")
      handle:close()
      return (result == "yes") and 1 or 0
    end
    return 0
  end,

  glob = function(pattern, nosuf, list)
    -- Proper glob implementation
    local result = {}
    
    -- Handle pattern like "/path/*"
    local dir = pattern:gsub("/%*$", "")
    
    -- Use find to get files
    local handle = io.popen('find "' .. dir .. '" -maxdepth 1 -type f 2>/dev/null')
    if handle then
      for line in handle:lines() do
        table.insert(result, line)
      end
      handle:close()
    end
    
    if list then
      return result
    else
      return table.concat(result, "\n")
    end
  end,

  executable = function(cmd)
    return MockVim._state.executables and MockVim._state.executables[cmd] or 0
  end,

  filereadable = function(path)
    local info = MockVim._state.files[path]
    return (info and info.type == "file") and 1 or 0
  end,

  readfile = function(path)
    local info = MockVim._state.files[path]
    if info and info.content then
      local lines = {}
      for line in (info.content .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
      end
      return lines
    end
    return {}
  end,

  delete = function(path)
    MockVim._state.files[path] = nil
    return 0
  end,

  tempname = function()
    return "/tmp/test_" .. tostring(os.time()) .. "_" .. tostring(math.random(10000))
  end,

  json_encode = function(t)
    -- Simple JSON encoder for testing
    if type(t) ~= "table" then return tostring(t) end
    local parts = {}
    local is_array = true
    for k, v in pairs(t) do
      if type(k) ~= "number" then
        is_array = false
        break
      end
    end
    if is_array then
      for i, v in ipairs(t) do
        table.insert(parts, MockVim.fn.json_encode(v))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      for k, v in pairs(t) do
        local key = '"' .. tostring(k) .. '"'
        local value = type(v) == "string" and ('"' .. v .. '"') or MockVim.fn.json_encode(v)
        table.insert(parts, key .. ":" .. value)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end,

  json_decode = function(s)
    -- Simple JSON decoder for testing
    return {}
  end,

  shellescape = function(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
  end,

  system = function(cmd)
    return ""
  end,

  jobstart = function() return 1 end,
  jobwait = function() return {0} end,
  jobstop = function() end,
}

MockVim.api = {
  nvim_buf_get_name = function(buf)
    return MockVim._state.current_buffer_name or ""
  end,

  nvim_create_user_command = function(name, fn, opts)
    MockVim._state.commands[name] = {fn = fn, opts = opts}
  end,

  nvim_create_autocmd = function(event, opts)
    table.insert(MockVim._state.autocmds, {event = event, opts = opts})
  end,

  nvim_get_current_buf = function() return 1 end,
  nvim_buf_get_option = function() return "" end,
  nvim_buf_set_option = function() end,
}

MockVim.uv = {
  fs_stat = function(path)
    -- First check mock state
    local info = MockVim._state.files[path]
    if info then
      return info
    end
    -- Fall back to actual filesystem for temp files
    local f = io.open(path, "r")
    if f then
      f:close()
      return { type = "file" }
    end
    -- Check if it's a directory
    local ok = os.execute("test -d " .. path .. " 2>/dev/null")
    if ok then
      return { type = "directory" }
    end
    return nil
  end,

  cwd = function() return MockVim._state.cwd end,
}

MockVim.loop = MockVim.uv  -- alias

MockVim.lsp = {
  get_clients = function()
    return MockVim._state.lsp_clients
  end,

  get_active_clients = function()
    return MockVim._state.lsp_clients
  end,
}

MockVim.v = {
  shell_error = 0,
}

MockVim.log = {
  levels = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
  }
}

MockVim.notify = function(msg, level)
  -- Store notifications for testing
  if not MockVim._state.notifications then
    MockVim._state.notifications = {}
  end
  table.insert(MockVim._state.notifications, {msg = msg, level = level})
end

MockVim.tbl_deep_extend = function(behavior, ...)
  local result = {}
  for _, t in ipairs({...}) do
    for k, v in pairs(t or {}) do
      if type(v) == "table" and type(result[k]) == "table" then
        result[k] = MockVim.tbl_deep_extend(behavior, result[k], v)
      else
        result[k] = v
      end
    end
  end
  return result
end

MockVim.tbl_map = function(fn, t)
  local result = {}
  for k, v in pairs(t) do
    result[k] = fn(v)
  end
  return result
end

MockVim.deepcopy = function(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = MockVim.deepcopy(v)
  end
  return copy
end

MockVim.inspect = function(t)
  return tostring(t)
end

MockVim.islist = function(t)
  if type(t) ~= "table" then return false end
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count == #t
end

MockVim.defer_fn = function(fn, delay)
  -- In tests, execute immediately or skip
  if MockVim._state.defer_immediate then
    fn()
  end
end

-- Helper to reset mock state
function MockVim.reset()
  MockVim._state = {
    cwd = "/test/project",
    files = {},
    commands = {},
    autocmds = {},
    lsp_clients = {},
    notifications = {},
  }
end

-- Helper to set up file system state
function MockVim.setFile(path, content)
  MockVim._state.files[path] = {
    type = "file",
    content = content,
    size = #content,
  }
end

function MockVim.setDirectory(path)
  MockVim._state.files[path] = {
    type = "directory",
  }
end

return MockVim
