describe("HotReload", function()
  local TestUtils = require("test_utils")
  local hot
  local temp_dir

  setup(function()
    local project_root = TestUtils.get_project_root()
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    hot = require("hotreload")
  end)

  before_each(function()
    temp_dir = TestUtils.create_temp_dir()
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("file change detection", function()
    it("should initialize state with hash", function()
      local file_path = temp_dir .. "/test.lua"
      TestUtils.write_file(file_path, "version 1")

      local state = {
        scriptPath = file_path
      }

      hot.init(state)

      -- Should set _lastHash
      assert.is_number(state._lastHash)
      assert.is_true(state._lastHash > 0)
    end)

    it("should detect file change", function()
      local file_path = temp_dir .. "/test.lua"
      TestUtils.write_file(file_path, "version 1")

      local state = {
        scriptPath = file_path
      }

      hot.init(state)
      local initial_hash = state._lastHash

      -- Modify file
      TestUtils.write_file(file_path, "version 2 - changed content")

      -- Update should detect change (pass enough time to bypass debounce)
      local changed = hot.update(state, 1.0)

      assert.is_true(changed)
      assert.is_not.equals(initial_hash, state._lastHash)
    end)

    it("should not detect change if file unchanged", function()
      local file_path = temp_dir .. "/test.lua"
      TestUtils.write_file(file_path, "version 1")

      local state = {
        scriptPath = file_path
      }

      hot.init(state)

      -- Update without changing file (pass enough time)
      local changed = hot.update(state, 1.0)

      assert.is_false(changed)
    end)

    it("should respect debounce time", function()
      local file_path = temp_dir .. "/test.lua"
      TestUtils.write_file(file_path, "version 1")

      local state = {
        scriptPath = file_path,
        _debounce = 10  -- Set high debounce
      }

      hot.init(state)

      -- Immediate update should be debounced
      local changed = hot.update(state, 0.01)

      -- Should return false because debounce is active
      assert.is_false(changed)
    end)

    it("should handle missing file", function()
      local state = {
        scriptPath = temp_dir .. "/nonexistent.lua"
      }

      -- Should not error
      hot.init(state)
      local changed = hot.update(state, 1.0)

      assert.is_false(changed)
    end)
  end)
end)
