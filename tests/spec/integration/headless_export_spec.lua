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
      local project_root = TestUtils.get_project_root()
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

      assert.is_true(config.enabled)
      assert.equals(5, config.ticks)
      assert.equals("output.png", config.output)
      assert.equals("game", config.capture)
      assert.is_table(config.inputs)
    end)

    it("should parse inputs correctly", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")
      local state = {}

      local args = {
        "--headless",
        "--inputs", "B1=true,B5=false,N1=0.5,N2=0.75"
      }

      local config = headless.parse_args(args, state)

      -- The implementation stores inputs as "B1", "N1" keys (not nested tables)
      assert.is_true(config.inputs["B1"])
      assert.is_false(config.inputs["B5"])
      assert.equals(0.5, config.inputs["N1"])
      assert.equals(0.75, config.inputs["N2"])
    end)
  end)

  describe("canvas export", function()
    it("should export canvas to image data", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")

      -- Create mock canvas
      local canvas = MockLove.graphics.newCanvas(96, 64)

      -- Export to temp file
      local temp_file = "/tmp/test_canvas_export_" .. os.time() .. ".png"
      local ok, err = headless.export_canvas(canvas, temp_file, "png")

      assert.is_true(ok)
      
      -- Clean up
      os.remove(temp_file)
    end)

    it("should return error for nil canvas", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")

      local ok, err = headless.export_canvas(nil, "/tmp/test.png", "png")

      assert.is_false(ok)
      assert.equals("canvas is nil", err)
    end)
  end)

  describe("format auto-detection", function()
    it("should detect PNG format from extension", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")
      local state = {}

      -- parse_args auto-detects format from extension
      local args = {"--headless", "--output", "output.png"}
      local config = headless.parse_args(args, state)
      
      assert.equals("png", config.format)
    end)

    it("should detect JPG format from extension", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")
      local state = {}

      local args = {"--headless", "--output", "output.jpg"}
      local config = headless.parse_args(args, state)
      
      assert.equals("jpg", config.format)
    end)

    it("should use explicit format over extension", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")
      local state = {}

      local args = {"--headless", "--output", "output.png", "--format", "jpg"}
      local config = headless.parse_args(args, state)
      
      assert.equals("jpg", config.format)
    end)
  end)

  describe("generate_export_path", function()
    it("should generate path with timestamp", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

      local headless = require("headless")

      local path = headless.generate_export_path("/tmp", "game", "png")

      assert.is_string(path)
      assert.is_true(path:match("^/tmp/export_game_") ~= nil)
      assert.is_true(path:match("%.png$") ~= nil)
    end)
  end)
end)
