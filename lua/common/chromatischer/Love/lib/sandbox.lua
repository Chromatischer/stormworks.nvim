-- Sandbox: loads and runs the user microcontroller script in an isolated env
local state = require('lib.state')
local logger = require('lib.logger')
local storm = require('lib.storm_api')

local sandbox = {
  env = nil,
}

local safe_globals = {
  "assert","error","ipairs","next","pairs","pcall","select","tonumber","tostring","type","unpack","xpcall","print",
}

local safe_tables = {
  math = math,
  string = string,
  table = table,
}

local function read_file(path)
  local f, err = io.open(path, 'rb')
  if not f then return nil, err end
  local content = f:read('*a')
  f:close()
  return content
end

local function make_env()
  local env = {}
  -- Whitelist globals
  for _,k in ipairs(safe_globals) do env[k] = _G[k] end
  for k,v in pairs(safe_tables) do env[k] = v end
  -- Attach Stormworks-like API
  storm.bind_to_env(env)
  -- Prevent access to os, io, debug, package, love, require by default
  env._G = env
  return env
end

local function load_chunk(code, chunkname, env)
  local fn, err = loadstring(code, chunkname)
  if not fn then return nil, err end
  if setfenv then setfenv(fn, env) end
  return fn
end

function sandbox.load_script()
  if not state.scriptPath then
    logger.append("[error] No --script path provided")
    return false, "no script"
  end
  local code, err = read_file(state.scriptPath)
  if not code then
    logger.append("[error] Failed to read script: " .. tostring(err))
    return false, err
  end
  local env = make_env()
  local fn, lerr = load_chunk(code, '@'..state.scriptPath, env)
  if not fn then
    logger.append("[error] load error: " .. tostring(lerr))
    return false, lerr
  end
  local ok, runerr = xpcall(fn, debug.traceback)
  if not ok then
    logger.append("[error] runtime error during load: " .. tostring(runerr))
    state.lastError = runerr
    state.running = false
    return false, runerr
  end
  sandbox.env = env
  logger.append(string.format("[info] Loaded %s", state.scriptPath))
  return true
end

local function safe_call(name)
  if not sandbox.env then return true end
  local fn = sandbox.env[name]
  if type(fn) ~= 'function' then return true end
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    logger.append("[error] "..name..": "..tostring(err))
    state.lastError = err
    if state.pauseOnError then state.running = false end
    return false, err
  end
  return true
end

function sandbox.tick()
  return safe_call('onTick')
end

function sandbox.draw()
  -- Drawing must occur with canvases bound; handled in storm.draw_user_onDraw
  return safe_call('onDraw')
end

function sandbox.reload()
  local ok, err = sandbox.load_script()
  if ok then
    logger.append("[info] Reloaded script")
    state.lastError = nil
    return true
  else
    logger.append("[error] Reload failed: " .. tostring(err))
    return false, err
  end
end

return sandbox
