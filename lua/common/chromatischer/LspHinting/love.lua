-- Stormworks Microcontroller LSP hinting
-- Consolidated editor-only API stubs for IntelliSense and diagnostics.
-- No runtime behavior is implemented here.

--- @diagnostic disable: lowercase-global

-- Input API
input = {}

--- Get boolean value from an input channel
--- @param ch integer
--- @return boolean
function input.getBool(ch) end

--- Get numeric value from an input channel
--- @param ch integer
--- @return number
function input.getNumber(ch) end

-- Output API
output = {}

--- Set boolean value on an output channel
--- @param ch integer
--- @param v boolean
function output.setBool(ch, v) end

--- Set numeric value on an output channel
--- @param ch integer
--- @param v number
function output.setNumber(ch, v) end

-- Property API
property = {}

--- Get numeric property value
--- @param name string
--- @return number
function property.getNumber(name) end

--- Get text property value
--- @param name string
--- @return string
function property.getText(name) end

--- Get boolean property value
--- @param name string
--- @return boolean
function property.getBool(name) end

-- Screen (game canvas) drawing API
screen = {}

--- Set current draw color for the main screen
--- @param r integer 0-255
--- @param g integer 0-255
--- @param b integer 0-255
--- @param a integer|nil 0-255 (default 255)
function screen.setColor(r, g, b, a) end

--- Set line width for subsequent primitives on the main screen
--- @param w number
function screen.setLineWidth(w) end

--- Draw outlined rectangle on the main screen
--- @param x number
--- @param y number
--- @param width number
--- @param height number
function screen.drawRect(x, y, width, height) end

--- Draw filled rectangle on the main screen
--- @param x number
--- @param y number
--- @param width number
--- @param height number
function screen.drawRectF(x, y, width, height) end

--- Draw outlined circle on the main screen
--- @param x number center x
--- @param y number center y
--- @param radius number
function screen.drawCircle(x, y, radius) end

--- Draw filled circle on the main screen
--- @param x number center x
--- @param y number center y
--- @param radius number
function screen.drawCircleF(x, y, radius) end

--- Draw a line on the main screen
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
function screen.drawLine(x1, y1, x2, y2) end

--- Draw text on the main screen
--- @param x number
--- @param y number
--- @param text string
function screen.drawText(x, y, text) end

--- Get main screen width in pixels
--- @return integer width
function screen.getWidth() end

--- Get main screen height in pixels
--- @return integer height
function screen.getHeight() end

--- Clear main screen with optional color
--- @param r integer|nil 0-255 (default 0)
--- @param g integer|nil 0-255 (default 0)
--- @param b integer|nil 0-255 (default 0)
--- @param a integer|nil 0-255 (default 255)
function screen.clear(r, g, b, a) end

-- Debug canvas drawing API (available via global 'dbg' when enabled)
dbg = {}

--- Set current debug draw color
--- @param r integer 0-255
--- @param g integer 0-255
--- @param b integer 0-255
--- @param a integer|nil 0-255 (default 255)
function dbg.setColor(r, g, b, a) end

--- Set line width for subsequent debug lines/rects/circles
--- @param w number
function dbg.setLineWidth(w) end

--- Draw outlined rectangle on debug canvas
--- @param x number
--- @param y number
--- @param width number
--- @param height number
function dbg.drawRect(x, y, width, height) end

--- Draw filled rectangle on debug canvas
--- @param x number
--- @param y number
--- @param width number
--- @param height number
function dbg.drawRectF(x, y, width, height) end

--- Draw outlined circle on debug canvas
--- @param x number center x
--- @param y number center y
--- @param radius number
function dbg.drawCircle(x, y, radius) end

--- Draw filled circle on debug canvas
--- @param x number center x
--- @param y number center y
--- @param radius number
function dbg.drawCircleF(x, y, radius) end

--- Draw a line on debug canvas
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
function dbg.drawLine(x1, y1, x2, y2) end

--- Draw text on debug canvas
--- @param x number
--- @param y number
--- @param text string
function dbg.drawText(x, y, text) end

--- Get debug canvas width in pixels
--- @return integer width
function dbg.getWidth() end

--- Get debug canvas height in pixels
--- @return integer height
function dbg.getHeight() end

--- Clear debug canvas with optional color
--- @param r integer|nil 0-255 (default 0)
--- @param g integer|nil 0-255 (default 0)
--- @param b integer|nil 0-255 (default 0)
--- @param a integer|nil 0-255 (default 255)
function dbg.clear(r, g, b, a) end

-- Time API
time = {}

--- Seconds per tick
--- @return number
function time.getDelta() end

-- Lifecycle hooks provided by MC scripts

---@alias MicrocontrollerConfig {tick?:number, tiles?:string|{x:integer,y:integer}, scale?:integer, debugCanvas?:boolean, debugCanvasSize?:{w:integer,h:integer}, properties?:table, input_simulator?: InputSimulator, input_simulator_config?: table}
---@alias InputSimulator fun(ctx: SimulatorCtx) | InputSimulatorTable

--- Configure the microcontroller and editor environment
--- Return a table such as:
--- { tick = 60, tiles = "3x2" or {x=3,y=2}, scale = 2, debugCanvas = true, debugCanvasSize = { w=320, h=180 }, properties = { MyNumber = 1 } }
--- @return MicrocontrollerConfig config
function onAttatch() end

--- Called every simulation tick
function onTick() end

--- Draw to the main screen
function onDraw() end

--- Draw to the debug canvas (if enabled)
function onDebugDraw() end

--------------------------------------------------------------------------------
-- Input Simulator LSP Hinting (types only)
--------------------------------------------------------------------------------

---@class SimulatorInputCtx
---@field setBool fun(ch: integer, v: boolean)
---@field setNumber fun(ch: integer, v: number)
---@field getBool fun(ch: integer): boolean
---@field getNumber fun(ch: integer): number

---@class SimulatorTimeCtx
---@field getDelta fun(): number

---@class SimulatorCtx
---@field input SimulatorInputCtx
---@field properties table<string, any>
---@field time SimulatorTimeCtx

---@class InputSimulatorTable
---@field onInit fun(ctx: SimulatorCtx, cfg: table|nil)|nil
---@field onTick fun(ctx: SimulatorCtx)
---@field onDebugDraw fun()|nil
