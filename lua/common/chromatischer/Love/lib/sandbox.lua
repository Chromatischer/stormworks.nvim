-- Sandbox: loads and runs the user microcontroller script in an isolated env
local state = require('lib.state')
local logger = require('lib.logger')
local storm = require('lib.storm_api')

local sandbox = { env = nil }

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
  -- Prevent access to os, io, debug, package, love by default
  env._G = env

  -- Provide a safe require that only loads Lua files from whitelisted folders (state.libPaths)
  local loaded = {}
  local function safe_require(modname)
    if type(modname) ~= 'string' then return nil, 'module name must be a string' end
    if loaded[modname] ~= nil then return loaded[modname] end
    local rel = modname:gsub('%.', '/')
    local tried = {}
    for _,root in ipairs(state.libPaths or {}) do
      -- Try root/rel.lua then root/rel/init.lua
      local candidates = {
        (root .. '/' .. rel .. '.lua'),
        (root .. '/' .. rel .. '/init.lua'),
      }
      for _,cand in ipairs(candidates) do
        local f = io.open(cand, 'rb')
        if f then
          local src = f:read('*a'); f:close()
          local chunk, perr = load_chunk(src, '@'..cand, env)
          if not chunk then
            return error('error loading module '..modname..': '..tostring(perr))
          end
          local ok, ret = xpcall(chunk, debug.traceback)
          if not ok then
            error('error running module '..modname..': '..tostring(ret))
          end
          -- require semantics: if module returns a value, cache it; otherwise true
          if ret == nil then ret = true end
          loaded[modname] = ret
          return ret
        else
          table.insert(tried, cand)
        end
      end
    end
    error("module '"..modname.."' not found in whitelisted lib paths. Tried: "..table.concat(tried, ', '))
  end
  env.require = safe_require
  env.package = nil -- keep blocked
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
  -- If the MC defines onAttatch (note: spelled as requested), allow it to configure runtime
  if type(env.onAttatch) == 'function' then
    local okAttach, cfgOrErr = xpcall(env.onAttatch, debug.traceback)
    if not okAttach then
      logger.append("[error] onAttatch: " .. tostring(cfgOrErr))
    else
      local cfg = cfgOrErr
      if type(cfg) == 'table' then
        -- Expected shape: { tick=number, tiles={x=int,y=int} | tiles="3x2", scale=int, debugCanvas=bool, properties=table }
        -- Respect CLI overrides if present
        local overrides = state.cliOverrides or {}
        if cfg.tick and not overrides.tick then state.tickRate = tonumber(cfg.tick) or state.tickRate end
        if cfg.scale and not overrides.scale then state.gameCanvasScale = tonumber(cfg.scale) or state.gameCanvasScale end
        if cfg.debugCanvas ~= nil and not overrides.debugCanvas then state.debugCanvasEnabled = not not cfg.debugCanvas end
        -- tiles
        if not overrides.tiles and cfg.tiles then
          if type(cfg.tiles) == 'string' then
            local x,y = tostring(cfg.tiles):match('^(%d+)%D+(%d+)$')
            if x and y then
              state.tilesX = tonumber(x) or state.tilesX
              state.tilesY = tonumber(y) or state.tilesY
            end
          elseif type(cfg.tiles) == 'table' then
            if tonumber(cfg.tiles.x) then state.tilesX = tonumber(cfg.tiles.x) end
            if tonumber(cfg.tiles.y) then state.tilesY = tonumber(cfg.tiles.y) end
          end
          state.properties.screenTilesX = state.tilesX
          state.properties.screenTilesY = state.tilesY
        end
        -- Optional debug canvas size
        if cfg.debugCanvasSize and type(cfg.debugCanvasSize) == 'table' then
          if tonumber(cfg.debugCanvasSize.w) then state.debugCanvasW = tonumber(cfg.debugCanvasSize.w) end
          if tonumber(cfg.debugCanvasSize.h) then state.debugCanvasH = tonumber(cfg.debugCanvasSize.h) end
        end
        -- Properties passthrough
        if type(cfg.properties) == 'table' then
          for k,v in pairs(cfg.properties) do state.properties[k] = v end
        end
      else
        logger.append('[warn] onAttatch did not return a table; ignoring')
      end
    end
  end
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
