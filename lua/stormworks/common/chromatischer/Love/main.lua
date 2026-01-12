-- Main entry point for the Stormworks Microcontroller Debugger (LÖVE)
local state = require("lib.state")
local ui = require("lib.ui")
local canvases = require("lib.canvases")
local logger = require("lib.logger")
local sandbox = require("lib.sandbox")
local hot = require("lib.hotreload")
local detach = require("lib.detach")

local function parse_args(args)
  local i = 1
  local log_truncate = false
  while i <= #args do
    local a = args[i]
    if a == "--script" and args[i + 1] then
      state.scriptPath = args[i + 1]
      i = i + 2
      -- default whitelist: directory of the script
      if state.scriptPath then
        local dir = state.scriptPath:match("^(.*)/[^/]+$")
        if dir then
          state.libPaths = state.libPaths or {}
          table.insert(state.libPaths, dir)
        end
      end
    elseif (a == "--lib" or a == "--libs") and args[i + 1] then
      state.libPaths = state.libPaths or {}
      local p = args[i + 1]
      -- Expand ~ to HOME for convenience when running manually
      if type(p) == "string" and p:sub(1, 1) == "~" then
        local home = os and os.getenv and os.getenv("HOME") or nil
        if home then
          p = home .. p:sub(2)
        end
      end
      table.insert(state.libPaths, p)
      print("Added lib root from CLI: " .. tostring(p))
      i = i + 2
    elseif a == "--log-file" and args[i + 1] then
      local p = args[i + 1]
      if type(p) == "string" and p:sub(1, 1) == "~" then
        local home = os and os.getenv and os.getenv("HOME") or nil
        if home then p = home .. p:sub(2) end
      end
      local ok, err = logger.enable_file(p, { truncate = log_truncate })
      if not ok then
        print("[logger] failed to enable file logging: " .. tostring(err))
      else
        print("[logger] writing to " .. tostring(p))
      end
      i = i + 2
    elseif a == "--log-truncate" then
      log_truncate = true
      -- If a file is already open, re-open in truncate mode
      local current = logger.get_file_path and logger.get_file_path() or nil
      if current then
        local ok, err = logger.enable_file(current, { truncate = true })
        if not ok then
          print("[logger] failed to truncate log file: " .. tostring(err))
        else
          print("[logger] truncated log file: " .. tostring(current))
        end
      end
      i = i + 1
    elseif a == "--detached" and args[i + 1] then
      state.detached = { enabled = true, which = tostring(args[i + 1]) }
      i = i + 2
    elseif a == "--tiles" and args[i + 1] then
      local s = args[i + 1]
      local x, y = s:match("^(%d+)%D+(%d+)$")
      state.tilesX = tonumber(x) or state.tilesX
      state.tilesY = tonumber(y) or state.tilesY
      state.properties.screenTilesX = state.tilesX
      state.properties.screenTilesY = state.tilesY
      if state.cliOverrides then
        state.cliOverrides.tiles = true
      end
      i = i + 2
    elseif a == "--tick" and args[i + 1] then
      state.tickRate = tonumber(args[i + 1]) or state.tickRate
      if state.cliOverrides then
        state.cliOverrides.tick = true
      end
      i = i + 2
    elseif a == "--scale" and args[i + 1] then
      state.gameCanvasScale = tonumber(args[i + 1]) or state.gameCanvasScale
      if state.cliOverrides then
        state.cliOverrides.scale = true
      end
      i = i + 2
    -- Enable user debug canvas (512x512 for onDebugDraw callbacks)
    elseif a == "--user-debug" and args[i + 1] then
      local v = tostring(args[i + 1])
      state.userDebugCanvasEnabled = (v == "true" or v == "1" or v == "on")
      if state.cliOverrides then
        state.cliOverrides.userDebug = true
      end
      i = i + 2
    -- Enable UI layer debug overlay (panel boundaries, hit areas)
    elseif a == "--debug-canvas" and args[i + 1] then
      local v = tostring(args[i + 1])
      state.debugOverlayEnabled = (v == "true" or v == "1" or v == "on")
      if state.cliOverrides then
        state.cliOverrides.debugOverlay = true
      end
      i = i + 2
    elseif a == "--max-error-repeats" and args[i + 1] then
      state.maxErrorRepeats = tonumber(args[i + 1]) or state.maxErrorRepeats
      i = i + 2
    elseif a == "--props" and args[i + 1] then
      local s = args[i + 1]
      for key, val in s:gmatch("([^,=]+)=([^,]+)") do
        local num = tonumber(val)
        if val == "true" or val == "false" then
          state.properties[key] = (val == "true")
        elseif num then
          state.properties[key] = num
        else
          state.properties[key] = val
        end
      end
      i = i + 2
    elseif a == "--inspector-hide-functions" and args[i + 1] then
      local v = tostring(args[i + 1])
      state.inspector.hideFunctions = (v == "true" or v == "1")
      i = i + 2
    elseif a == "--inspector-group-by-origin" and args[i + 1] then
      local v = tostring(args[i + 1])
      state.inspector.groupByOrigin = (v == "true" or v == "1")
      i = i + 2
    elseif a == "--inspector-pinned" and args[i + 1] then
      -- Comma-separated list of pinned global names
      local s = args[i + 1]
      state.inspector.pinnedGlobals = {}
      for name in s:gmatch("[^,]+") do
        local trimmed = name:match("^%s*(.-)%s*$")
        if trimmed and #trimmed > 0 then
          table.insert(state.inspector.pinnedGlobals, trimmed)
        end
      end
      i = i + 2
    else
      i = i + 1
    end
  end
end

function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest", 1)
  -- Ensure pixel-perfect lines/shapes
  if love.graphics.setLineStyle then
    love.graphics.setLineStyle("rough")
  end
  if love.graphics.setPointStyle then
    love.graphics.setPointStyle("rough")
  end
  logger.install_print_capture()
  parse_args(args or {})
  
  -- Check for headless mode
  local headless_config = nil
  for _, arg in ipairs(args or {}) do
    if arg == "--headless" then
      local headless_module = require("lib.headless")
      headless_config = headless_module.parse_args(args, state)
      break
    end
  end
  
  if headless_config and headless_config.enabled then
    -- Headless mode: run and export, then exit
    local headless_module = require("lib.headless")
    
    -- Expand package.path for lib roots (same as normal mode)
    do
      local parts = {}
      for _, root in ipairs(state.libPaths or {}) do
        local r = tostring(root):gsub("/+$", "")
        table.insert(parts, r .. "/?.lua")
        table.insert(parts, r .. "/?/init.lua")
      end
      if #parts > 0 then
        package.path = table.concat(parts, ";") .. ";" .. package.path
      end
    end
    
    -- Load user script
    local ok, err = sandbox.load_script()
    if not ok then
      local result = {
        success = false,
        errors = {"Failed to load script: " .. tostring(err)},
        ticks_run = 0,
        outputs = {},
        images = {},
      }
      headless_module.write_result(result, headless_config)
      love.event.quit(1)
      return
    end
    
    -- Run headless export
    local success = headless_module.run(state, sandbox, canvases, headless_config)
    love.event.quit(success and 0 or 1)
    return
  end
  
  -- Debug: print lib roots and resulting package.path for troubleshooting
  do
    print("LIB ROOTS (raw):")
    for i, p in ipairs(state.libPaths or {}) do
      print("  [" .. i .. "] " .. tostring(p))
    end
  end
  -- Expand package.path to include any whitelisted lib roots
  do
    local parts = {}
    local normalized = {}
    for _, root in ipairs(state.libPaths or {}) do
      local r = tostring(root)
      -- Strip trailing slashes and resolve ./ and ../ as best as we can with love.filesystem? Nah, use raw
      r = r:gsub("/+$", "")
      table.insert(normalized, r)
      -- Support both flat files and tree modules
      table.insert(parts, r .. "/?.lua")
      table.insert(parts, r .. "/?/init.lua")
    end
    print("LIB ROOTS (normalized):")
    for i, p in ipairs(normalized) do
      print("  [" .. i .. "] " .. tostring(p))
    end
    if #parts > 0 then
      package.path = table.concat(parts, ";") .. ";" .. package.path
    end
  end
  print("PACKAGE.PATH:")
  print(package.path)

  if state.detached.enabled then
    -- Detached viewer mode: display frames written by the main process
    love.window.setTitle(
      "Stormworks Debugger — " .. tostring(state.detached.which):gsub("^%l", string.upper) .. " (Detached)"
    )
    -- smaller minimums are fine for a single panel
    local _, _, flags = love.window.getMode()
    flags.resizable = true
    flags.minwidth = 256
    flags.minheight = 256
    love.window.setMode(love.graphics.getWidth(), love.graphics.getHeight(), flags)
    state._viewer = { img = nil, seq = -1, iw = 0, ih = 0 }
    -- Intercept OS window close to perform the same as clicking X in UI
    function love.quit()
      local base = "detached/" .. tostring(state.detached.which)
      love.filesystem.write(base .. "/closed.txt", "1")
      -- Returning nothing or false allows quit to proceed
    end
    print("VIEWER READY: " .. state.detached.which)
    return
  end

  -- Fonts
  local fontPath = "fonts/JetBrainsMono-Regular.ttf"
  state.fonts.ui = love.graphics.newFont(fontPath, 13)
  state.fonts.uiHeader = love.graphics.newFont(fontPath, 15)
  state.fonts.mono = love.graphics.newFont(fontPath, 13)
  love.graphics.setFont(state.fonts.ui)

  -- Load user script before creating canvases so onAttatch() can configure sizes
  do
    local ok, err = sandbox.load_script()
    if not ok then
      logger.append("[error] load_script failed: " .. tostring(err))
      -- keep running; UI will show error
    end
  end
  canvases.recreateAll()
  hot.init(state)
  detach.init()

  print("READY")
end

local function try_tick()
  state.lastTickDt = 1 / (state.tickRate > 0 and state.tickRate or 60)
  local ok = sandbox.tick()
  if ok then
    state.tickCount = state.tickCount + 1
  end
end

-- Perform canvas export
local function perform_export()
  local headless = require("lib.headless")
  local format = state.export.format or "png"
  local capture = state.export.capture or "game"

  -- Determine base directory (script directory or cwd)
  local base_dir = nil
  if state.scriptPath then
    base_dir = state.scriptPath:match("^(.*)/[^/]+$")
  end

  local results = {}
  local errors = {}

  if capture == "both" then
    -- Export both canvases
    local game_path = headless.generate_export_path(base_dir, "game", format)
    local debug_path = headless.generate_export_path(base_dir, "debug", format)

    local ok1, err1 = headless.export_canvas(canvases.game, game_path, format)
    local ok2, err2 = headless.export_canvas(canvases.debug, debug_path, format)

    if ok1 then
      table.insert(results, game_path)
    else
      table.insert(errors, "Export game failed: " .. tostring(err1))
    end

    if ok2 then
      table.insert(results, debug_path)
    else
      table.insert(errors, "Export debug failed: " .. tostring(err2))
    end
  else
    -- Export single canvas
    local canvas = (capture == "game") and canvases.game or canvases.debug
    local path = headless.generate_export_path(base_dir, capture, format)

    local ok, err = headless.export_canvas(canvas, path, format)
    if ok then
      table.insert(results, path)
    else
      table.insert(errors, "Export failed: " .. tostring(err))
    end
  end

  -- Show results
  if #results > 0 then
    state.export.lastPath = results[1]
    state.export.lastTime = love.timer.getTime()
    state.export.showModal = false
    for _, path in ipairs(results) do
      logger.append("[info] Exported: " .. path)
    end
  end

  -- Show errors
  for _, err in ipairs(errors) do
    logger.append("[error] " .. err)
  end
end

-- Pin persistence: save pinned globals to .microproject
local pin_persist_state = {
  lastSaveTime = 0,
  debounceDelay = 1.0, -- seconds
}

local function serialize_lua_value(v, indent, visited)
  indent = indent or 0
  visited = visited or {}
  local t = type(v)
  if t == "string" then
    return string.format("%q", v)
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  elseif t == "nil" then
    return "nil"
  elseif t == "table" then
    -- Check for cyclic reference
    if visited[v] then
      return "{--[[cyclic reference]]}"
    end
    visited[v] = true
    
    local parts = {}
    local count = 0
    for _ in pairs(v) do count = count + 1 end
    if count == #v and count > 0 then
      -- Array-style
      for _, val in ipairs(v) do
        table.insert(parts, serialize_lua_value(val, indent + 1, visited))
      end
      return "{ " .. table.concat(parts, ", ") .. " }"
    else
      -- Object-style
      local ws = string.rep("  ", indent + 1)
      local sorted_keys = {}
      for k in pairs(v) do table.insert(sorted_keys, k) end
      table.sort(sorted_keys, function(a, b) return tostring(a) < tostring(b) end)
      for _, k in ipairs(sorted_keys) do
        local key_str
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
          key_str = k
        else
          key_str = "[" .. serialize_lua_value(k, 0, visited) .. "]"
        end
        table.insert(parts, ws .. key_str .. " = " .. serialize_lua_value(v[k], indent + 1, visited))
      end
      local close_ws = string.rep("  ", indent)
      return "{\n" .. table.concat(parts, ",\n") .. "\n" .. close_ws .. "}"
    end
  end
  return "nil"
end

local function find_microproject_path()
  if not state.scriptPath then return nil end
  local dir = state.scriptPath:match("^(.*)/[^/]+$")
  while dir and #dir > 0 do
    local config_path = dir .. "/.microproject"
    local f = io.open(config_path, "r")
    if f then
      f:close()
      return config_path
    end
    local parent = dir:match("^(.*)/[^/]+$")
    if not parent or parent == dir then break end
    dir = parent
  end
  return nil
end

local function persist_inspector_pins()
  local config_path = find_microproject_path()
  if not config_path then return false, "no .microproject found" end

  -- Read existing config
  local ok, cfg = pcall(dofile, config_path)
  if not ok or type(cfg) ~= "table" then
    cfg = {}
  end

  -- Update inspector section
  cfg.inspector = cfg.inspector or {}
  cfg.inspector.pinnedGlobals = state.inspector.pinnedGlobals or {}

  -- Write back
  local out = io.open(config_path, "w")
  if not out then return false, "cannot write to " .. config_path end
  out:write("return " .. serialize_lua_value(cfg, 0, {}) .. "\n")
  out:close()
  logger.append("[info] Saved pinned globals to " .. config_path)
  return true
end

local function check_pin_persistence()
  if not ui._inspectorPinsChanged then return end
  local now = love.timer.getTime()
  if now - pin_persist_state.lastSaveTime < pin_persist_state.debounceDelay then return end
  pin_persist_state.lastSaveTime = now
  ui._inspectorPinsChanged = false
  persist_inspector_pins()
end

function love.update(dt)
  if state.detached.enabled then
    -- Poll for updated frame in detached viewer
    local base = "detached/" .. tostring(state.detached.which)
    -- Quit signal
    local qinfo = love.filesystem.getInfo(base .. "/quit.txt")
    if qinfo then
      local q = love.filesystem.read(base .. "/quit.txt") or "0"
      if tostring(q):match("^%s*1") then
        love.event.quit()
        return
      end
    end
    if love.filesystem.getInfo(base .. "/seq.txt") then
      local s = love.filesystem.read(base .. "/seq.txt") or "-1"
      local seq = tonumber(s) or -1
      if seq ~= state._viewer.seq then
        state._viewer.seq = seq
        local data = love.filesystem.read(base .. "/frame.png")
        if data then
          local fileData = love.filesystem.newFileData(data, "frame.png")
          local imgData = love.image.newImageData(fileData)
          state._viewer.iw, state._viewer.ih = imgData:getWidth(), imgData:getHeight()
          state._viewer.img = love.graphics.newImage(imgData)
          state._viewer.img:setFilter("nearest", "nearest")
        end
      end
    end
    return
  end
  -- Hot reload check
  if state.hotReload and hot.update(state, dt) then
    local ok = sandbox.reload()
    if ok then
      canvases.recreateAll()
    end
  end

  local step_dt = 1 / (state.tickRate > 0 and state.tickRate or 60)
  if state.running then
    state.accumulator = state.accumulator + dt
    local guard = 0
    while state.accumulator >= step_dt and guard < 10 do
      try_tick()
      state.accumulator = state.accumulator - step_dt
      guard = guard + 1
    end
  elseif state.singleStep then
    try_tick()
    state.singleStep = false
  end

  -- Check if export was requested
  if state.export.doExport then
    state.export.doExport = false
    perform_export()
  end

  -- Check if inspector pins need to be persisted (debounced)
  check_pin_persistence()
end

function love.draw()
  if state.detached.enabled then
    love.graphics.clear(0.08, 0.08, 0.09, 1)
    local img = state._viewer and state._viewer.img
    if img then
      local iw, ih = state._viewer.iw, state._viewer.ih
      local ww, wh = love.graphics.getWidth(), love.graphics.getHeight()
      -- integer scale clamp 1..8
      local sx = math.floor(math.min(8, math.max(1, math.floor(ww / iw))))
      local sy = math.floor(math.min(8, math.max(1, math.floor(wh / ih))))
      local scale = math.max(1, math.min(sx, sy))
      local dx = math.floor((ww - iw * scale) / 2)
      local dy = math.floor((wh - ih * scale) / 2)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(img, dx, dy, 0, scale, scale)
    else
      love.graphics.setColor(1, 1, 1, 0.6)
      love.graphics.print("Waiting for " .. tostring(state.detached.which) .. " frame…", 16, 16)
    end
    return
  end
  love.graphics.clear(0.1, 0.1, 0.11, 1)
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  ui.layout(w, h)
  ui.draw_toolbar()
  -- If panels are detached, don't draw them in the main window
  if not detach.is_enabled("inputs") then
    ui.draw_inputs()
  end

  -- Game canvas draw
  local gamePanel = ui.draw_game_canvas()
  canvases.ensure()
  if not ui.minimized.game then
    -- Render to game canvas by calling user onDraw
    local canvas_prev = love.graphics.getCanvas()
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    -- Draw game canvas content
    canvases.withTarget("game", function(api)
      api.clear(0, 0, 0, 255)
      -- Provide screen.* API during onDraw
      if sandbox.env and type(sandbox.env.onDraw) == "function" then
        local ok, err = xpcall(sandbox.env.onDraw, debug.traceback)
        if not ok then
          logger.append("[error] onDraw: " .. tostring(err))
          state.lastError = err
          if state.pauseOnError then
            state.running = false
          end
        end
      end
    end)
    love.graphics.setCanvas(canvas_prev)
    love.graphics.push()
    love.graphics.translate(gamePanel.x, gamePanel.y)
    canvases.drawToScreen({ x = 0, y = 0 }, "game")
    love.graphics.pop()
  end

  -- Debug canvas: always render content if enabled so detached viewer updates
  if state.userDebugCanvasEnabled then
    canvases.ensure()
    -- Always render into debug canvas (even when detached/minimized)
    do
      local canvas_prev = love.graphics.getCanvas()
      love.graphics.setCanvas()
      canvases.withTarget("debug", function(api)
        api.clear(0, 0, 0, 255)
        -- Simulator debug draw first (if provided)
        if sandbox.sim and sandbox.sim.hooks and type(sandbox.sim.hooks.onDebugDraw) == "function" then
          local okSim, errSim = xpcall(sandbox.sim.hooks.onDebugDraw, debug.traceback)
          if not okSim then
            logger.append("[error] input_simulator onDebugDraw: " .. tostring(errSim))
          end
        end
        if sandbox.env and type(sandbox.env.onDebugDraw) == "function" then
          local ok, err = xpcall(sandbox.env.onDebugDraw, debug.traceback)
          if not ok then
            logger.append("[error] onDebugDraw: " .. tostring(err))
          end
        end
      end)
      love.graphics.setCanvas(canvas_prev)
    end
    -- Draw to main window only if not detached and not minimized
    if not detach.is_enabled("debug") then
      local dbgPanel = ui.draw_debug_canvas_center()
      if not ui.minimized.debug and dbgPanel and dbgPanel.x then
        love.graphics.push()
        love.graphics.translate(dbgPanel.x, dbgPanel.y)
        canvases.drawToScreen({ x = 0, y = 0 }, "debug")
        love.graphics.pop()
      end
    end
  end

  if not ui.mergedOutputs and not detach.is_enabled("outputs") then
    ui.draw_outputs()
  end
  ui.draw_log(logger)

  if state.lastError then
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.print("ERROR: " .. tostring(state.lastError), 16, 48)
  end

  -- Draw export modal and toast (on top of everything)
  ui.draw_export_modal()
  ui.draw_export_toast()

  -- UI debug overlay (for development)
  if state.debugOverlayEnabled then
    ui.draw_debug_overlay()
  end

  -- Update detached frame writers after rendering
  detach.update()
end

function love.keypressed(key)
  if state.detached.enabled then
    if key == "escape" then
      love.event.quit()
    end
    return
  end

  -- Handle inspector edit mode - highest priority
  if ui._inspectorEdit and ui._inspectorEdit.active then
    if key == "return" or key == "kpenter" then
      -- Accept edit and update value
      local text = ui._inspectorEdit.text
      local valueType = ui._inspectorEdit.valueType
      local globalKey = ui._inspectorEdit.globalKey
      local newValue = nil
      local valid = false

      if valueType == "string" then
        newValue = text
        valid = true
      elseif valueType == "number" then
        newValue = tonumber(text)
        valid = (newValue ~= nil)
      elseif valueType == "boolean" then
        if text == "true" then
          newValue = true
          valid = true
        elseif text == "false" then
          newValue = false
          valid = true
        end
      end

      if valid and sandbox.env and globalKey then
        sandbox.env[globalKey] = newValue
        logger.append("[inspector] Set " .. globalKey .. " = " .. tostring(newValue))
      end

      ui._inspectorEdit.active = false
      ui._inspectorEdit.path = nil
      ui._inspectorEdit.globalKey = nil
      ui._inspectorEdit.text = ""
      ui._inspectorEdit.valueType = nil
      return
    elseif key == "escape" then
      -- Cancel edit
      ui._inspectorEdit.active = false
      ui._inspectorEdit.path = nil
      ui._inspectorEdit.globalKey = nil
      ui._inspectorEdit.text = ""
      ui._inspectorEdit.valueType = nil
      return
    elseif key == "backspace" then
      ui._inspectorEdit.text = ui._inspectorEdit.text:sub(1, -2)
      return
    end
    -- All other keys fall through to textinput handler
    return
  end

  -- Handle search input - block all keybinds when search is active
  if state.logUI.searchActive then
    if key == "backspace" then
      state.logUI.searchText = state.logUI.searchText:sub(1, -2)
    elseif key == "escape" then
      state.logUI.searchActive = false
      state.logUI.searchText = ""
    end
    return  -- Block all other keybinds when search box is active
  end

  if key == "space" then
    state.running = not state.running
    -- Reset error tracking when manually resuming
    if state.running then
      state.errorCount = 0
      state.errorSignature = nil
    end
  elseif key == "n" then
    state.singleStep = true
  elseif key == "r" then
    local ok = sandbox.reload()
    if ok then
      canvases.recreateAll()
    end
  elseif key == "=" or key == "+" then
    state.gameCanvasScale = math.min(8, state.gameCanvasScale + 1)
  elseif key == "-" then
    state.gameCanvasScale = math.max(1, state.gameCanvasScale - 1)
  elseif key == "d" then
    state.userDebugCanvasEnabled = not state.userDebugCanvasEnabled
    canvases.recreateAll()
  elseif key == "f5" then
    detach.toggle("game")
  elseif key == "f6" then
    if not state.userDebugCanvasEnabled then
      state.userDebugCanvasEnabled = true
      canvases.recreateAll()
    end
    detach.toggle("debug")
  elseif key == "]" then
    local factor = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 10 or 20
    state.tickRate = math.min(480, math.max(10, math.floor(state.tickRate + factor)))
  elseif key == "[" then
    local factor = (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) and 10 or 20
    state.tickRate = math.min(480, math.max(10, math.floor(state.tickRate - factor)))
  elseif key == "e" then
    state.export.showModal = not state.export.showModal
  elseif key == "escape" then
    if state.export.showModal then
      state.export.showModal = false
    end
  end
end

local function sanitizeTextInput(text, current, maxLen)
  -- Remove control characters to avoid display issues or control sequences
  text = text:gsub("%c", "")

  if maxLen and maxLen > 0 then
    local currentLen = current and #current or 0
    local remaining = maxLen - currentLen
    if remaining <= 0 then
      return current or ""
    end
    if #text > remaining then
      text = text:sub(1, remaining)
    end
  end

  return (current or "") .. text
end

function love.textinput(text)
  if ui._inspectorEdit and ui._inspectorEdit.active then
    ui._inspectorEdit.text = sanitizeTextInput(text, ui._inspectorEdit.text, 1024)
    return
  end
  if state.logUI.searchActive then
    state.logUI.searchText = sanitizeTextInput(text, state.logUI.searchText, 256)
  end
end

function love.mousepressed(x, y, button)
  if ui.mousepressed then
    ui.mousepressed(x, y, button)
  end
end
function love.mousereleased(x, y, button)
  if ui.mousereleased then
    ui.mousereleased(x, y, button)
  end
end
function love.mousemoved(x, y, dx, dy)
  if ui.mousemoved then
    ui.mousemoved(x, y, dx, dy)
  end
end
function love.wheelmoved(dx, dy)
  if ui.wheelmoved then
    ui.wheelmoved(dx, dy)
  end
end

-- Clamp excessive window sizes and enforce minimums to keep layouts sensible
local MAIN_MIN_W, MAIN_MIN_H = 800, 600
local MAIN_MAX_W, MAIN_MAX_H = 2560, 1600 -- "reasonable" upper bounds
local function clamp_window_dimensions(w, h, minw, minh, maxw, maxh)
  w = math.max(minw, math.min(maxw, w))
  h = math.max(minh, math.min(maxh, h))
  return w, h
end

function love.resize(w, h)
  if state._resizing_guard then
    return
  end
  if state.detached and state.detached.enabled then
    -- Detached viewer: limit to 1..8x of canvas size plus margin
    local iw, ih = 128, 128
    if state._viewer and state._viewer.iw and state._viewer.iw > 0 then
      iw, ih = state._viewer.iw, state._viewer.ih
    elseif state.detached.which == "game" then
      iw, ih = state.tilesX * state.tileSize, state.tilesY * state.tileSize
    elseif state.detached.which == "debug" then
      iw, ih = state.debugCanvasW, state.debugCanvasH
    end
    local minw, minh = math.max(256, iw + 64), math.max(256, ih + 64)
    local maxw, maxh = iw * 8 + 64, ih * 8 + 64
    local cw, ch = clamp_window_dimensions(w, h, minw, minh, maxw, maxh)
    if cw ~= w or ch ~= h then
      state._resizing_guard = true
      local _, _, flags = love.window.getMode()
      love.window.setMode(cw, ch, flags)
      state._resizing_guard = false
    end
    return
  end

  -- Main window clamp
  local cw, ch = clamp_window_dimensions(w, h, MAIN_MIN_W, MAIN_MIN_H, MAIN_MAX_W, MAIN_MAX_H)
  if cw ~= w or ch ~= h then
    state._resizing_guard = true
    local _, _, flags = love.window.getMode()
    love.window.setMode(cw, ch, flags)
    state._resizing_guard = false
  end
end
