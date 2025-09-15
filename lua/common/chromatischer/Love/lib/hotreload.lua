-- Hot-reload helper using content hash (works for external files)
local hot = {}

local function read_file(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local c = f:read('*a')
  f:close()
  return c
end

local function djb2_hash(s)
  local hash = 5381
  for i = 1, #s do
    -- Use arithmetic instead of bitwise to stay LuaJIT/Lua 5.1 compatible
    hash = (hash * 33 + string.byte(s, i)) % 2147483647
  end
  return hash
end

function hot.init(state)
  local content = state.scriptPath and read_file(state.scriptPath) or nil
  state._lastHash = content and djb2_hash(content) or 0
  state._debounce = 0
end

function hot.update(state, dt)
  state._debounce = (state._debounce or 0) - dt
  if state._debounce > 0 then return false end
  local content = state.scriptPath and read_file(state.scriptPath) or nil
  if content then
    local h = djb2_hash(content)
    if h ~= state._lastHash then
      state._lastHash = h
      state._debounce = 0.2
      return true
    end
  end
  return false
end

return hot
