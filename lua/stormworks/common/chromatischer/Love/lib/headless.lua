-- Headless rendering and export functionality
local M = {}

local function to255(r, g, b, a)
  a = a or 255
  return r / 255, g / 255, b / 255, a / 255
end

-- Parse headless-specific CLI args
function M.parse_args(args, state)
  local config = {
    enabled = false,
    ticks = 1,
    output = nil,
    format = nil, -- auto-detect from extension
    capture = "debug", -- "debug", "game", or "both"
    inputs = {}, -- parsed input values
    inputs_json = nil,
    outputs_json = nil, -- path to write outputs
    result_json = nil, -- path to write complete result
  }

  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "--headless" then
      config.enabled = true
      i = i + 1
    elseif a == "--ticks" and args[i + 1] then
      config.ticks = tonumber(args[i + 1]) or 1
      i = i + 2
    elseif a == "--output" and args[i + 1] then
      config.output = args[i + 1]
      i = i + 2
    elseif a == "--format" and args[i + 1] then
      config.format = args[i + 1]
      i = i + 2
    elseif a == "--capture" and args[i + 1] then
      config.capture = args[i + 1]
      i = i + 2
    elseif a == "--inputs" and args[i + 1] then
      -- Parse inline inputs: "B1=true,N1=0.5,N2=123"
      local spec = args[i + 1]
      for key, val in spec:gmatch("([^,=]+)=([^,]+)") do
        local ch_type = key:sub(1, 1) -- 'B' or 'N'
        local ch_num = tonumber(key:sub(2))
        if ch_type and ch_num and ch_num >= 1 and ch_num <= 32 then
          if ch_type == "B" then
            config.inputs["B" .. ch_num] = (val == "true" or val == "1")
          elseif ch_type == "N" then
            config.inputs["N" .. ch_num] = tonumber(val) or 0
          end
        end
      end
      i = i + 2
    elseif a == "--inputs-json" and args[i + 1] then
      config.inputs_json = args[i + 1]
      i = i + 2
    elseif a == "--outputs-json" and args[i + 1] then
      config.outputs_json = args[i + 1]
      i = i + 2
    elseif a == "--result-json" and args[i + 1] then
      config.result_json = args[i + 1]
      i = i + 2
    elseif a == "--debug-canvas-size" and args[i + 1] then
      local s = args[i + 1]
      local w, h = s:match("^(%d+)%D+(%d+)$")
      if w and h then
        state.debugCanvasW = tonumber(w)
        state.debugCanvasH = tonumber(h)
      end
      i = i + 2
    else
      i = i + 1
    end
  end

  -- Auto-detect format from extension if not specified
  if config.output and not config.format then
    if config.output:match("%.png$") then
      config.format = "png"
    elseif config.output:match("%.jpe?g$") then
      config.format = "jpg"
    else
      config.format = "png" -- default
    end
  end

  return config
end

-- Load inputs from JSON file
local function load_inputs_json(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "cannot open " .. path
  end
  local content = f:read("*a")
  f:close()

  -- Simple JSON parser for our specific structure
  local inputs = {}
  -- Parse {"B": {"1": true, "2": false}, "N": {"1": 0.5, "5": 123}}
  for ch_type, ch_num, val in content:gmatch('"([BN])"%s*:%s*{[^}]*"(%d+)"%s*:%s*([^,}]+)') do
    local num = tonumber(ch_num)
    if num and num >= 1 and num <= 32 then
      if ch_type == "B" then
        inputs["B" .. num] = (val:match("true") ~= nil)
      elseif ch_type == "N" then
        inputs["N" .. num] = tonumber(val:match("[%d%.%-]+")) or 0
      end
    end
  end

  return inputs
end

-- Apply inputs to state
local function apply_inputs(config, state)
  -- Load from JSON file if specified
  if config.inputs_json then
    local inputs, err = load_inputs_json(config.inputs_json)
    if inputs then
      for k, v in pairs(inputs) do
        config.inputs[k] = v
      end
    else
      io.stderr:write("Warning: failed to load inputs from JSON: " .. tostring(err) .. "\n")
    end
  end

  -- Apply all inputs to state
  for k, v in pairs(config.inputs) do
    local ch_type = k:sub(1, 1)
    local ch_num = tonumber(k:sub(2))
    if ch_num then
      if ch_type == "B" then
        state.inputB[ch_num] = v
      elseif ch_type == "N" then
        state.inputN[ch_num] = v
      end
    end
  end
end

-- Collect outputs from state
local function collect_outputs(state)
  local outputs = { B = {}, N = {} }
  for i = 1, 32 do
    if state.outputB[i] ~= false then
      outputs.B[tostring(i)] = state.outputB[i]
    end
    if state.outputN[i] ~= 0 then
      outputs.N[tostring(i)] = state.outputN[i]
    end
  end
  return outputs
end

-- Simple JSON encoder for result
local function encode_json(t)
  local parts = {}
  table.insert(parts, "{")
  local first = true
  for k, v in pairs(t) do
    if not first then
      table.insert(parts, ",")
    end
    first = false
    table.insert(parts, '"' .. tostring(k) .. '":')
    if type(v) == "string" then
      table.insert(parts, '"' .. v:gsub('"', '\\"') .. '"')
    elseif type(v) == "boolean" then
      table.insert(parts, tostring(v))
    elseif type(v) == "number" then
      table.insert(parts, tostring(v))
    elseif type(v) == "table" then
      table.insert(parts, encode_json(v))
    else
      table.insert(parts, "null")
    end
  end
  table.insert(parts, "}")
  return table.concat(parts)
end

-- Export canvas to image file (public for UI usage)
function M.export_canvas(canvas, path, format)
  if not canvas then
    return false, "canvas is nil"
  end

  local imgData = canvas:newImageData()
  local fileData = imgData:encode(format or "png")
  
  -- Write to file using standard Lua I/O (not love.filesystem for absolute paths)
  local f, err = io.open(path, "wb")
  if not f then
    return false, "cannot open output file: " .. tostring(err)
  end
  
  f:write(fileData:getString())
  f:close()
  
  return true
end

-- Generate export path with timestamp
function M.generate_export_path(base_dir, canvas_type, format)
  local timestamp = os.date("%Y%m%d_%H%M%S")
  local filename = string.format("export_%s_%s.%s", canvas_type, timestamp, format or "png")
  if base_dir and base_dir ~= "" then
    return base_dir:gsub("[/\\]$", "") .. "/" .. filename
  end
  return filename
end

-- Main headless execution
function M.run(state, sandbox, canvases, config)
  local result = {
    success = false,
    image = nil,
    images = {},
    ticks_run = 0,
    outputs = {},
    errors = {},
  }

  -- Validate required args
  if not config.output then
    table.insert(result.errors, "Missing required --output argument")
    M.write_result(result, config)
    return false
  end

  -- Apply inputs
  apply_inputs(config, state)

  -- Enable debug canvas if capturing it
  if config.capture == "debug" or config.capture == "both" then
    state.debugCanvasEnabled = true
  end

  -- Create canvases
  canvases.recreateAll()

  -- Run ticks
  for tick = 1, config.ticks do
    local ok = sandbox.tick()
    if ok then
      result.ticks_run = tick
    else
      table.insert(result.errors, "Tick " .. tick .. " failed")
      break
    end
  end

  -- Render to canvases
  local canvas_prev = love.graphics.getCanvas()
  love.graphics.setCanvas()

  -- Helper to render with API wrapper
  local function render_to_canvas(which, draw_fn)
    canvases.withTarget(which, function(api)
      api.clear(0, 0, 0, 255)
      if draw_fn then
        local ok, err = xpcall(draw_fn, debug.traceback)
        if not ok then
          table.insert(result.errors, "Error in " .. which .. " render: " .. tostring(err))
        end
      end
    end)
  end

  -- Render game canvas if needed
  if config.capture == "game" or config.capture == "both" then
    if sandbox.env and type(sandbox.env.onDraw) == "function" then
      render_to_canvas("game", sandbox.env.onDraw)
    end
  end

  -- Render debug canvas if needed
  if config.capture == "debug" or config.capture == "both" then
    if sandbox.env and type(sandbox.env.onDebugDraw) == "function" then
      render_to_canvas("debug", sandbox.env.onDebugDraw)
    end
  end

  love.graphics.setCanvas(canvas_prev)

  -- Export canvas(es)
  if config.capture == "both" then
    -- Export both canvases with suffix
    local base = config.output:gsub("(%.[^%.]+)$", "")
    local ext = config.output:match("(%.[^%.]+)$") or ".png"
    
    local game_path = base .. "_game" .. ext
    local debug_path = base .. "_debug" .. ext
    
    local ok1, err1 = M.export_canvas(canvases.game, game_path, config.format)
    local ok2, err2 = M.export_canvas(canvases.debug, debug_path, config.format)
    
    if ok1 then
      table.insert(result.images, game_path)
    else
      table.insert(result.errors, "Failed to export game canvas: " .. tostring(err1))
    end
    
    if ok2 then
      table.insert(result.images, debug_path)
    else
      table.insert(result.errors, "Failed to export debug canvas: " .. tostring(err2))
    end
    
    result.success = ok1 or ok2
    result.image = result.images[1]
  else
    -- Export single canvas
    local canvas = (config.capture == "game") and canvases.game or canvases.debug
    local ok, err = M.export_canvas(canvas, config.output, config.format)
    
    if ok then
      result.success = true
      result.image = config.output
      table.insert(result.images, config.output)
    else
      table.insert(result.errors, "Failed to export: " .. tostring(err))
    end
  end

  -- Collect outputs
  result.outputs = collect_outputs(state)

  -- Write outputs to separate JSON if requested
  if config.outputs_json then
    local f = io.open(config.outputs_json, "w")
    if f then
      f:write(encode_json(result.outputs))
      f:close()
    else
      table.insert(result.errors, "Failed to write outputs JSON")
    end
  end

  -- Write result
  M.write_result(result, config)
  
  return result.success
end

-- Write result to stdout and/or file
function M.write_result(result, config)
  local json = encode_json(result)
  
  -- Always write to stdout
  io.stdout:write(json .. "\n")
  io.stdout:flush()
  
  -- Write to file if requested
  if config.result_json then
    local f = io.open(config.result_json, "w")
    if f then
      f:write(json)
      f:close()
    end
  end
end

return M
