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

---@alias InputSimulator fun(ctx: SimulatorCtx) | InputSimulatorTable

-- Example usage:
--   ---@type InputSimulator
--   local sim = require('simulators.wave_and_toggle')
--   function onAttatch()
--     return { input_simulator = sim, input_simulator_config = { ... } }
--   end
