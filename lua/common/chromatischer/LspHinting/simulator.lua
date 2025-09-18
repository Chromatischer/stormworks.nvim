-- Stormworks Microcontroller LSP hinting (Simulator context)
-- Editor-only API stubs for IntelliSense and diagnostics. No runtime behavior.

--- @diagnostic disable: lowercase-global

--------------------------------------------------------------------------------
-- Input Simulator LSP Hinting (types only)
--------------------------------------------------------------------------------

---@class SimulatorInputCtx
---@field setBool fun(ch: integer, v: boolean)
---@field setNumber fun(ch: integer, v: number)
---@field getBool fun(ch: integer): boolean
---@field getNumber fun(ch: integer): number
SimulatorInputCtx = {}

---@class SimulatorTimeCtx
---@field getDelta fun(): number
function getDelta() end

---@class SimulatorCtx
---@field input SimulatorInputCtx
---@field properties table<string, any>
---@field time SimulatorTimeCtx
---@field touch { game: SimulatorTouchInfo, debug: SimulatorTouchInfo }
SimulatorCtx = {}

---@class SimulatorTouchInfo
---@field x integer    # canvas-local X (0..width-1)
---@field y integer    # canvas-local Y (0..height-1)
---@field left boolean # left mouse button currently held (was pressed inside)
---@field right boolean # right mouse button currently held (was pressed inside)
---@field inside boolean # is the pointer currently within the canvas rect
SimulatorTouchInfo = {}

---@class InputSimulatorTable
---@field onInit fun(ctx: SimulatorCtx, cfg: table|nil)|nil
---@field onTick fun(ctx: SimulatorCtx)
---@field onDebugDraw fun()|nil
InputSimulatorTable = {}

-- ---@alias InputSimulator fun(ctx: SimulatorCtx) | InputSimulatorTable

-- Example usage:
--   ---@type InputSimulator
--   local sim = require('simulators.wave_and_toggle')
--   function onAttatch()
--     return { input_simulator = sim, input_simulator_config = { ... } }
--   end
