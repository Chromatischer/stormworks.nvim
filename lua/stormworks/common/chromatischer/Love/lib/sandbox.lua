-- Sandbox: loads and runs the user microcontroller script in an isolated env
local state = require("lib.state")
local logger = require("lib.logger")
local storm = require("lib.storm_api")

local sandbox = { env = nil, sim = nil, globalOrigins = {} }

-- Helper: temporarily allow setmetatable within the sandbox env for specific phases
-- Only enabled during: onAttatch(), simulator onInit/onTick/onDebugDraw
local function with_setmetatable(fn, ...)
  local e = sandbox.env
  local had, prev = false, nil
  if e then
    prev = e.setmetatable
    had = prev ~= nil
    e.setmetatable = _G.setmetatable
  end
  local ok, res = xpcall(fn, debug.traceback, ...)
  if e then
    if had then
      e.setmetatable = prev
    else
      e.setmetatable = nil
    end
  end
  return ok, res
end

local safe_globals = {
  "assert",
  "error",
  "ipairs",
  "next",
  "pairs",
  "pcall",
  "select",
  "tonumber",
  "tostring",
  "type",
  "unpack",
  "xpcall",
  "print",
}

local safe_tables = {
  math = math,
  string = string,
  table = table,
}

local function read_file(path)
  local f, err = io.open(path, "rb")
  if not f then
    return nil, err
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function make_env()
  local env = {}
  -- Whitelist globals
  for _, k in ipairs(safe_globals) do
    env[k] = _G[k]
  end
  for k, v in pairs(safe_tables) do
    env[k] = v
  end
  -- Attach Stormworks-like API
  storm.bind_to_env(env)
  -- Provide editor-only type aliases to the env (no runtime cost)
  ---@type InputSimulator
  env._input_simulator_typehint = nil
  -- Prevent access to os, io, debug, love by default
  env._G = env
  -- Custom require that loads modules into the sandbox env and searches whitelisted lib roots
  do
    local loaded = {}
    local function load_chunk_from_file(path, chunkname)
      local f = io.open(path, "rb")
      if not f then
        return nil, "cannot open " .. path
      end
      local src = f:read("*a")
      f:close()
      local fn, err
      local loader = loadstring or load
      if loader == load and _VERSION ~= "Lua 5.1" then
        fn, err = load(src, chunkname or "@" .. path, "t", env)
      else
        fn, err = loadstring(src, chunkname or "@" .. path)
        if fn and setfenv then
          setfenv(fn, env)
        end
      end
      if not fn then
        return nil, err
      end
      return fn
    end
    local function safe_require(modname)
      if type(modname) ~= "string" then
        error("module name must be a string")
      end
      if loaded[modname] ~= nil then
        return loaded[modname]
      end
      -- Snapshot env keys before loading to track new globals
      local before_keys = {}
      for k in pairs(env) do before_keys[k] = true end
      local function track_new_globals()
        for k in pairs(env) do
          if not before_keys[k] and not sandbox.globalOrigins[k] then
            sandbox.globalOrigins[k] = modname
          end
        end
      end
      local rel = modname:gsub("%.", "/")
      local tried = {}
      for _, root in ipairs(state.libPaths or {}) do
        local candidates = {
          (root .. "/" .. rel .. ".lua"),
          (root .. "/" .. rel .. "/init.lua"),
        }
        for _, cand in ipairs(candidates) do
          local fn = load_chunk_from_file(cand, "@" .. cand)
          if fn then
            if logger and logger.append then
              logger.append("[require] loading " .. modname .. " from " .. cand)
            end
            local ok, ret = xpcall(fn, debug.traceback)
            if not ok then
              error("error running module " .. modname .. ": " .. tostring(ret))
            end
            if ret == nil then
              ret = true
            end
            loaded[modname] = ret
            if logger and logger.append then
              local note = ""
              if modname == "Vectors.vec3" then
                note = " Vec3=" .. tostring(env.Vec3)
              elseif modname == "Vectors.vec2" then
                note = " Vec2=" .. tostring(env.Vec2)
              elseif modname == "Vectors.Vectors" then
                note = " (post-load: Vec2=" .. tostring(env.Vec2) .. " Vec3=" .. tostring(env.Vec3) .. ")"
              end
              logger.append("[require] loaded " .. modname .. note)
            end
            track_new_globals()
            return ret
          else
            table.insert(tried, cand)
          end
        end
      end
      -- Try resolving via package.path entries ourselves so we can load into env
      do
        local path = package and package.path or nil
        if path then
          local relname = rel
          for patt in path:gmatch("[^;]+") do
            local cand = patt:gsub("%%%?.", "%%?") -- defensive
            cand = cand:gsub("%?", relname)
            local fn = load_chunk_from_file(cand, "@" .. cand)
            if fn then
              if logger and logger.append then
                logger.append("[require] package.path resolved " .. modname .. " from " .. cand)
              end
              local ok, ret = xpcall(fn, debug.traceback)
              if not ok then
                error("error running module " .. modname .. ": " .. tostring(ret))
              end
              if ret == nil then
                ret = true
              end
              loaded[modname] = ret
              track_new_globals()
              return ret
            else
              table.insert(tried, cand)
            end
          end
        end
      end
      -- As a last-last resort, try host require (will not pollute env globals)
      local ok, ret = pcall(require, modname)
      if ok then
        loaded[modname] = ret
        if logger and logger.append then
          logger.append("[require] host require resolved " .. modname .. " (globals not imported)")
        end
        return ret
      end
      error("module '" .. modname .. "' not found in whitelisted lib paths. Tried: " .. table.concat(tried, ", "))
    end
    env.require = safe_require
  end

  -- Override print to tag logs from main script
  env.print = function(...)
    local parts = {}
    for i = 1, select('#', ...) do
      parts[i] = tostring(select(i, ...))
    end
    local line = table.concat(parts, '\t')
    logger.append(line, "main")
  end

  return env
end

local function load_chunk(code, chunkname, env)
  -- LuaJIT/Lua 5.1: use loadstring + setfenv
  -- Lua 5.2+: use load with env param
  local loader = loadstring or load
  if loader == load and _VERSION ~= "Lua 5.1" then
    return load(code, chunkname, "t", env)
  else
    local fn, err = loadstring(code, chunkname)
    if not fn then
      return nil, err
    end
    if setfenv then
      setfenv(fn, env)
    end
    return fn
  end
end

function sandbox.load_script()
  -- Clear origin tracking for fresh load
  sandbox.globalOrigins = {}

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

  -- Snapshot env keys before running main script
  local before_keys = {}
  for k in pairs(env) do before_keys[k] = true end

  local fn, lerr = load_chunk(code, "@" .. state.scriptPath, env)
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

  -- Mark main script globals (those not from require)
  for k in pairs(env) do
    if not before_keys[k] and not sandbox.globalOrigins[k] then
      sandbox.globalOrigins[k] = "main"
    end
  end

  sandbox.env = env
  sandbox.sim = nil -- clear any previous simulator on fresh load
  -- Reset simulator tracking
  for i = 1, 32 do
    state.simulatorDriven.inputB[i] = false
    state.simulatorDriven.inputN[i] = false
  end
  -- If the MC defines onAttatch (note: spelled as requested), allow it to configure runtime
  if type(env.onAttatch) == "function" then
    -- Allow setmetatable during onAttatch (and any require calls inside it)
    local okAttach, cfgOrErr = with_setmetatable(env.onAttatch)
    if not okAttach then
      logger.append("[error] onAttatch: " .. tostring(cfgOrErr))
      state.lastError = cfgOrErr
      if state.pauseOnError then
        state.running = false
      end
    else
      local cfg = cfgOrErr
      if type(cfg) == "table" then
        -- Expected shape: { tick=number, tiles={x=int,y=int} | tiles="3x2", scale=int, debugCanvas=bool, properties=table }
        -- Respect CLI overrides if present
        local overrides = state.cliOverrides or {}
        if cfg.tick and not overrides.tick then
          state.tickRate = tonumber(cfg.tick) or state.tickRate
        end
        if cfg.scale and not overrides.scale then
          state.gameCanvasScale = tonumber(cfg.scale) or state.gameCanvasScale
        end
        if cfg.debugCanvas ~= nil and not overrides.userDebug then
          state.userDebugCanvasEnabled = not not cfg.debugCanvas
        end
        -- tiles
        if not overrides.tiles and cfg.tiles then
          if type(cfg.tiles) == "string" then
            local x, y = tostring(cfg.tiles):match("^(%d+)%D+(%d+)$")
            if x and y then
              state.tilesX = tonumber(x) or state.tilesX
              state.tilesY = tonumber(y) or state.tilesY
            end
          elseif type(cfg.tiles) == "table" then
            if tonumber(cfg.tiles.x) then
              state.tilesX = tonumber(cfg.tiles.x)
            end
            if tonumber(cfg.tiles.y) then
              state.tilesY = tonumber(cfg.tiles.y)
            end
          end
          state.properties.screenTilesX = state.tilesX
          state.properties.screenTilesY = state.tilesY
        end
        -- Optional debug canvas size
        if cfg.debugCanvasSize and type(cfg.debugCanvasSize) == "table" then
          if tonumber(cfg.debugCanvasSize.w) then
            state.debugCanvasW = tonumber(cfg.debugCanvasSize.w)
          end
          if tonumber(cfg.debugCanvasSize.h) then
            state.debugCanvasH = tonumber(cfg.debugCanvasSize.h)
          end
        end
        -- Properties passthrough
        if type(cfg.properties) == "table" then
          for k, v in pairs(cfg.properties) do
            state.properties[k] = v
          end
        end

        -- I/O Tab system configuration
        if type(cfg.io_tabs) == "table" and cfg.io_tabs.enabled then
          state.ioTabs.enabled = true
          state.ioTabs.tabs = cfg.io_tabs.tabs or {}
          state.ioTabs.activeInputTab = cfg.io_tabs.default_tab or "all"
          state.ioTabs.activeOutputTab = cfg.io_tabs.default_tab or "all"
          -- Validate channel numbers (1-32)
          for _, tab in ipairs(state.ioTabs.tabs) do
            if tab.channels then
              for i, ch in ipairs(tab.channels) do
                if type(ch) ~= "number" or ch < 1 or ch > 32 then
                  logger.append(string.format("[warn] io_tabs: invalid channel %s in tab '%s'", tostring(ch), tab.name or "?"))
                end
              end
            end
          end
        end

        -- Input simulator support
        local sim = cfg.input_simulator
        if sim ~= nil then
          -- Normalize simulator hooks
          local hooks = nil
          if type(sim) == "function" then
            hooks = { onTick = sim }
          elseif type(sim) == "table" then
            hooks = sim
          else
            logger.append("[warn] input_simulator is not a function or table; ignoring")
          end
          if hooks then
            -- Build simulator context
            local function clampChannel(ch)
              ch = tonumber(ch)
              if not ch then
                return nil
              end
              ch = math.floor(ch)
              if ch < 1 or ch > 32 then
                return nil
              end
              return ch
            end
            local sim_ctx = {}
            sim_ctx.input = {}
            function sim_ctx.input.setBool(ch, v)
              ch = clampChannel(ch)
              if not ch then
                return
              end
              state.simulatorDriven.inputB[ch] = true
              state.inputB[ch] = not not v
            end
            function sim_ctx.input.setNumber(ch, v)
              ch = clampChannel(ch)
              if not ch then
                return
              end
              state.simulatorDriven.inputN[ch] = true
              local num = tonumber(v) or 0
              if num ~= num then
                num = 0
              end
              state.inputN[ch] = num
            end
            function sim_ctx.input.getBool(ch)
              ch = clampChannel(ch)
              if not ch then
                return false
              end
              return state.inputB[ch] or false
            end
            function sim_ctx.input.getNumber(ch)
              ch = clampChannel(ch)
              if not ch then
                return 0
              end
              return state.inputN[ch] or 0
            end
            sim_ctx.properties = state.properties -- read-only by convention
            sim_ctx.time = {
              getDelta = function()
                return state.lastTickDt
              end,
            }
            sim_ctx.touch = state.touch

            -- Override print for simulator to tag logs
            sim_ctx.print = function(...)
              local parts = {}
              for i = 1, select('#', ...) do
                parts[i] = tostring(select(i, ...))
              end
              local line = table.concat(parts, '\t')
              logger.append(line, "simulator")
            end

            sandbox.sim = { hooks = hooks, ctx = sim_ctx, cfg = cfg.input_simulator_config }
            -- Initialize simulator if it exposes onInit
            if type(hooks.onInit) == "function" then
              local okSim, errSim = with_setmetatable(function()
                return hooks.onInit(sim_ctx, cfg.input_simulator_config)
              end)
              if not okSim then
                logger.append("[error] input_simulator onInit: " .. tostring(errSim))
                state.lastError = errSim
                if state.pauseOnError then
                  state.running = false
                end
              end
            end
          end
        end
      else
        logger.append("[warn] onAttatch did not return a table; ignoring")
      end
    end
  end
  logger.append(string.format("[info] Loaded %s", state.scriptPath))
  return true
end

-- Load encouraging error messages from JSON
local error_messages = nil
local function load_error_messages()
  if error_messages then return error_messages end
  
  local json_path = "data/error_messages.json"
  local file = io.open(json_path, "r")
  if not file then
    -- Fallback message if file can't be loaded
    error_messages = { messages = { "Max consecutive errors reached. Time to reload and try again!" } }
    return error_messages
  end
  
  local content = file:read("*all")
  file:close()
  
  -- JSON parser that handles escaped quotes properly
  local messages = {}
  -- Pattern matches strings with proper escape handling
  -- Matches: " followed by (non-quote OR backslash+any char)* followed by "
  local i = 1
  while i <= #content do
    local start_pos = content:find('"', i)
    if not start_pos then break end
    
    -- Find the closing quote, accounting for escaped quotes
    local pos = start_pos + 1
    local str = ""
    local escaped = false
    
    while pos <= #content do
      local char = content:sub(pos, pos)
      
      if escaped then
        -- Handle escaped characters
        if char == '"' then
          str = str .. '"'
        elseif char == '\\' then
          str = str .. '\\'
        elseif char == 'n' then
          str = str .. '\n'
        elseif char == 't' then
          str = str .. '\t'
        elseif char == 'r' then
          str = str .. '\r'
        else
          -- Keep the backslash for unknown escapes
          str = str .. '\\' .. char
        end
        escaped = false
      elseif char == '\\' then
        escaped = true
      elseif char == '"' then
        -- Found the closing quote
        if str ~= "messages" then
          table.insert(messages, str)
        end
        i = pos + 1
        break
      else
        str = str .. char
      end
      
      pos = pos + 1
    end
    
    if pos > #content then
      -- Reached end without finding closing quote
      break
    end
  end
  
  error_messages = { messages = messages }
  return error_messages
end

-- Get a random encouraging message
local function get_error_limit_message()
  local msgs = load_error_messages()
  if #msgs.messages == 0 then
    return "Max consecutive errors reached. Time to reload and try again!"
  end
  math.randomseed(os.time() + state.tickCount)
  return msgs.messages[math.random(1, #msgs.messages)]
end

-- Track repeated errors and return true if threshold exceeded
local function track_error(err)
  -- Normalize error: strip line numbers (e.g., ":123:"), memory addresses (0x...), and extra whitespace
  local sig = tostring(err)
    :gsub(":%d+:", ":")  -- Remove line numbers like ":123:"
    :gsub(":%d+$", "")   -- Remove trailing line numbers
    :gsub("0x%x+", "")   -- Remove memory addresses
    :gsub("%s+", " ")    -- Normalize whitespace
  
  if sig == state.errorSignature then
    state.errorCount = state.errorCount + 1
  else
    state.errorSignature = sig
    state.errorCount = 1
  end
  
  return state.errorCount >= state.maxErrorRepeats
end

local function safe_call(name)
  if not sandbox.env then
    return true
  end
  local fn = sandbox.env[name]
  if type(fn) ~= "function" then
    return true
  end
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    logger.append("[error] " .. name .. ": " .. tostring(err))
    state.lastError = err
    
    -- Track repeated errors and pause if threshold exceeded
    if track_error(err) then
      logger.append("────────────────────────────────────────")
      logger.append("[info] " .. get_error_limit_message())
      logger.append("────────────────────────────────────────")
      state.running = false
    elseif state.pauseOnError then
      state.running = false
    end
    return false, err
  end
  return true
end

function sandbox.tick()
  -- 1) Simulator tick (pre-user)
  if sandbox.sim and sandbox.sim.hooks and type(sandbox.sim.hooks.onTick) == "function" then
    local okSim, errSim = with_setmetatable(function()
      return sandbox.sim.hooks.onTick(sandbox.sim.ctx)
    end)
    if not okSim then
      logger.append("[error] input_simulator onTick: " .. tostring(errSim))
      state.lastError = errSim
      
      -- Track repeated errors and pause if threshold exceeded
      if track_error(errSim) then
        logger.append("────────────────────────────────────────")
        logger.append("[info] " .. get_error_limit_message())
        logger.append("────────────────────────────────────────")
        state.running = false
      elseif state.pauseOnError then
        state.running = false
      end
      -- still attempt user onTick afterward if running isn't paused
    end
  end
  -- 2) User tick
  return safe_call("onTick")
end

function sandbox.draw()
  -- Drawing must occur with canvases bound; handled in storm.draw_user_onDraw
  -- Allow setmetatable within simulator onDebugDraw if present
  if sandbox.sim and sandbox.sim.hooks and type(sandbox.sim.hooks.onDebugDraw) == "function" then
    local okSim, errSim = with_setmetatable(function()
      return sandbox.sim.hooks.onDebugDraw(sandbox.sim.ctx)
    end)
    if not okSim then
      logger.append("[error] input_simulator onDebugDraw: " .. tostring(errSim))
      state.lastError = errSim
      
      -- Track repeated errors and pause if threshold exceeded
      if track_error(errSim) then
        logger.append("────────────────────────────────────────")
        logger.append("[info] " .. get_error_limit_message())
        logger.append("────────────────────────────────────────")
        state.running = false
      elseif state.pauseOnError then
        state.running = false
      end
    end
  end
  return safe_call("onDraw")
end

function sandbox.reload()
  local ok, err = sandbox.load_script()
  if ok then
    logger.append("[info] Reloaded script")
    state.lastError = nil
    state.errorCount = 0
    state.errorSignature = nil
    return true
  else
    logger.append("[error] Reload failed: " .. tostring(err))
    return false, err
  end
end

return sandbox
