describe("Headless", function()
  local MockLove = require("mock_love")
  local TestUtils = require("test_utils")
  local headless

  setup(function()
    -- Install LOVE mock
    _G.love = MockLove

    local project_root = TestUtils.get_project_root()
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

      assert.is_true(config.enabled)
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
      local args = {"--headless", "--capture", "game"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals("game", config.capture)
    end)

    it("should parse inline inputs", function()
      local args = {"--headless", "--inputs", "B1=true,N1=0.5"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.is_table(config.inputs)
      assert.is_true(config.inputs["B1"])
      assert.equals(0.5, config.inputs["N1"])
    end)

    it("should default to 1 tick if not specified", function()
      local args = {"--headless"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals(1, config.ticks)
    end)

    it("should default to debug capture if not specified", function()
      local args = {"--headless"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals("debug", config.capture)
    end)

    it("should auto-detect png format from extension", function()
      local args = {"--headless", "--output", "test.png"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals("png", config.format)
    end)

    it("should auto-detect jpg format from extension", function()
      local args = {"--headless", "--output", "test.jpg"}
      local state = {}
      local config = headless.parse_args(args, state)

      assert.equals("jpg", config.format)
    end)
  end)

  describe("export_canvas", function()
    it("should return error when canvas is nil", function()
      local ok, err = headless.export_canvas(nil, "/tmp/test.png", "png")

      assert.is_false(ok)
      assert.equals("canvas is nil", err)
    end)

    it("should export canvas to file", function()
      local canvas = MockLove.graphics.newCanvas(100, 100)
      
      -- Note: This will actually try to write to the file system
      -- In a real test environment, we'd mock io.open as well
      local ok, err = headless.export_canvas(canvas, "/tmp/test_headless_export.png", "png")

      assert.is_true(ok)
      os.remove("/tmp/test_headless_export.png")
    end)
  end)

  describe("generate_export_path", function()
    it("should generate path with timestamp", function()
      local path = headless.generate_export_path("/tmp", "game", "png")

      assert.is_string(path)
      assert.is_true(path:match("^/tmp/export_game_") ~= nil)
      assert.is_true(path:match("%.png$") ~= nil)
    end)

    it("should handle empty base_dir", function()
      local path = headless.generate_export_path("", "debug", "png")

      assert.is_string(path)
      assert.is_true(path:match("^export_debug_") ~= nil)
    end)
  end)
end)
