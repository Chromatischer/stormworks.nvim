describe("Headless", function()
  local MockLove = require("mock_love")
  local headless

  setup(function()
    -- Install LOVE mock
    _G.love = MockLove

    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    headless = require("headless")
  end)

  before_each(function()
    MockLove.reset()
  end)

  describe("parse_args", function()
    it("should parse --headless flag", function()
      local args = {"--headless"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.is_true(config.headless)
    end)

    it("should parse --ticks argument", function()
      local args = {"--headless", "--ticks", "10"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals(10, config.ticks)
    end)

    it("should parse --output argument", function()
      local args = {"--headless", "--output", "test.png"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals("test.png", config.output)
    end)

    it("should parse --capture argument", function()
      local args = {"--headless", "--capture", "debug"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals("debug", config.capture)
    end)

    it("should parse inline inputs", function()
      local args = {"--headless", "--inputs", "B1=true,N1=0.5"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.is_table(config.inputs)
      assert.is_true(config.inputs.B and config.inputs.B["1"])
      assert.equals(0.5, config.inputs.N and config.inputs.N["1"])
    end)

    it("should default to 1 tick if not specified", function()
      local args = {"--headless"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals(1, config.ticks)
    end)

    it("should default to game capture if not specified", function()
      local args = {"--headless"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals("game", config.capture)
    end)
  end)

  describe("apply_inputs", function()
    it("should apply boolean inputs to state", function()
      local state = {
        inputB = {},
        inputN = {}
      }
      for i = 1, 32 do
        state.inputB[i] = false
        state.inputN[i] = 0
      end

      local inputs = {
        B = {
          ["1"] = true,
          ["5"] = false
        }
      }

      headless.apply_inputs(state, inputs)

      assert.is_true(state.inputB[1])
      assert.is_false(state.inputB[5])
    end)

    it("should apply number inputs to state", function()
      local state = {
        inputB = {},
        inputN = {}
      }
      for i = 1, 32 do
        state.inputB[i] = false
        state.inputN[i] = 0
      end

      local inputs = {
        N = {
          ["1"] = 0.5,
          ["2"] = 0.75
        }
      }

      headless.apply_inputs(state, inputs)

      assert.equals(0.5, state.inputN[1])
      assert.equals(0.75, state.inputN[2])
    end)
  end)

  describe("collect_outputs", function()
    it("should collect outputs from state", function()
      local state = {
        outputB = {},
        outputN = {}
      }
      for i = 1, 32 do
        state.outputB[i] = false
        state.outputN[i] = 0
      end

      state.outputB[1] = true
      state.outputN[2] = 0.5

      local outputs = headless.collect_outputs(state)

      assert.is_table(outputs.B)
      assert.is_table(outputs.N)
      assert.is_true(outputs.B["1"])
      assert.equals(0.5, outputs.N["2"])
    end)
  end)
end)
