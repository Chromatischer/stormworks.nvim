describe("Headless Export Integration", function()
  local MockLove = require("mock_love")
  local TestUtils = require("test_utils")

  setup(function()
    -- Install LOVE mock
    _G.love = MockLove
  end)

  before_each(function()
    MockLove.reset()
  end)

  describe("CLI argument parsing", function()
    it("should parse headless mode with all arguments", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")
      local state = {}

      local args = {
        "--headless",
        "--ticks", "5",
        "--output", "output.png",
        "--capture", "game",
        "--inputs", "B1=true,N1=0.5"
      }

      local config = headless.parse_args(args, state)

      assert.is_true(config.headless)
      assert.equals(5, config.ticks)
      assert.equals("output.png", config.output)
      assert.equals("game", config.capture)
      assert.is_table(config.inputs)
    end)

    it("should parse inputs correctly", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")
      local state = {}

      local args = {
        "--headless",
        "--inputs", "B1=true,B5=false,N1=0.5,N2=0.75"
      }

      local config = headless.parse_args(args, state)

      assert.is_true(config.inputs.B["1"])
      assert.is_false(config.inputs.B["5"])
      assert.equals(0.5, config.inputs.N["1"])
      assert.equals(0.75, config.inputs.N["2"])
    end)
  end)

  describe("input application", function()
    it("should apply inputs to state before execution", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")
      local state = {
        inputB = {},
        inputN = {}
      }

      -- Initialize state
      for i = 1, 32 do
        state.inputB[i] = false
        state.inputN[i] = 0
      end

      local inputs = {
        B = {["1"] = true, ["2"] = true},
        N = {["3"] = 0.5, ["4"] = 0.75}
      }

      headless.apply_inputs(state, inputs)

      assert.is_true(state.inputB[1])
      assert.is_true(state.inputB[2])
      assert.equals(0.5, state.inputN[3])
      assert.equals(0.75, state.inputN[4])
    end)
  end)

  describe("output collection", function()
    it("should collect outputs from state after execution", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")
      local state = {
        outputB = {},
        outputN = {}
      }

      -- Initialize state with some outputs
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

  describe("canvas export", function()
    it("should export canvas to image data", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")

      -- Create mock canvas
      local canvas = MockLove.graphics.newCanvas(96, 64)

      -- Export (with mock)
      local image_data = headless.export_canvas(canvas, "test.png", "png")

      assert.is_not_nil(image_data)
    end)
  end)

  describe("format detection", function()
    it("should detect PNG format from extension", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")

      local format = headless.detect_format("output.png", nil)
      assert.equals("png", format)
    end)

    it("should detect JPG format from extension", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")

      local format = headless.detect_format("output.jpg", nil)
      assert.equals("jpg", format)
    end)

    it("should use explicit format over extension", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")

      local format = headless.detect_format("output.png", "jpg")
      assert.equals("jpg", format)
    end)
  end)
end)
