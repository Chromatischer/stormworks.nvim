describe("Logger", function()
  local TestUtils = require("test_utils")
  local logger
  local temp_file

  setup(function()
    local project_root = TestUtils.get_project_root()
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    logger = require("logger")
  end)

  before_each(function()
    -- Reset logger state
    logger.lines = {}
    logger._fh = nil
    logger._file_path = nil
    logger.max_lines = 1000
  end)

  after_each(function()
    -- Clean up file handle
    logger.disable_file()
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
      local ok, err = logger.enable_file(temp_file, {truncate = true})

      assert.is_true(ok, "enable_file should return true: " .. tostring(err))
      assert.is_not_nil(logger._fh)

      logger.append("test message", "main")

      -- Disable file logging (closes the file handle)
      logger.disable_file()

      local f = io.open(temp_file, "r")
      local content = f:read("*a")
      f:close()

      assert.truthy(content:find("test message"))
    end)

    it("should return file path", function()
      temp_file = "/tmp/test_logger_path_" .. os.time() .. ".log"
      logger.enable_file(temp_file, {truncate = true})

      assert.equals(temp_file, logger.get_file_path())
      
      logger.disable_file()
    end)
  end)
end)
