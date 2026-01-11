describe("Logger", function()
  local logger
  local temp_file

  setup(function()
    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    logger = require("logger")
  end)

  before_each(function()
    -- Reset logger state
    logger.lines = {}
    logger.file = nil
    logger.max_lines = 1000
  end)

  after_each(function()
    if logger.file then
      logger.file:close()
      logger.file = nil
    end
    if temp_file then
      os.remove(temp_file)
      temp_file = nil
    end
  end)

  describe("append", function()
    it("should append log lines", function()
      logger.append("test message", "main")

      assert.equals(1, #logger.lines)
      assert.equals("test message", logger.lines[1].text)
      assert.equals("main", logger.lines[1].source)
    end)

    it("should handle multiple appends", function()
      logger.append("line 1", "main")
      logger.append("line 2", "main")
      logger.append("line 3", "main")

      assert.equals(3, #logger.lines)
    end)

    it("should respect max_lines limit", function()
      logger.max_lines = 5

      for i = 1, 10 do
        logger.append("line " .. i, "main")
      end

      -- Should only keep last 5 lines
      assert.equals(5, #logger.lines)
      assert.equals("line 6", logger.lines[1].text)
      assert.equals("line 10", logger.lines[5].text)
    end)
  end)

  describe("getLines", function()
    it("should return recent lines", function()
      logger.append("line 1", "main")
      logger.append("line 2", "main")
      logger.append("line 3", "main")

      local lines = logger.getLines(10)

      assert.equals(3, #lines)
    end)

    it("should limit returned lines", function()
      for i = 1, 10 do
        logger.append("line " .. i, "main")
      end

      local lines = logger.getLines(5)

      assert.equals(5, #lines)
    end)
  end)

  describe("enable_file", function()
    it("should enable file logging", function()
      temp_file = "/tmp/test_logger_" .. os.time() .. ".log"
      logger.enable_file(temp_file, false)

      assert.is_not_nil(logger.file)

      logger.append("test", "main")

      -- Close and check file
      logger.file:close()
      logger.file = nil

      local f = io.open(temp_file, "r")
      local content = f:read("*a")
      f:close()

      assert.truthy(content:find("test"))
    end)
  end)
end)
