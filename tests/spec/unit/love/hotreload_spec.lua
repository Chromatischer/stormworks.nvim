describe("HotReload", function()
  local TestUtils = require("test_utils")
  local hot
  local temp_dir

  setup(function()
    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    hot = require("hotreload")
  end)

  before_each(function()
    temp_dir = TestUtils.create_temp_dir()
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("hash calculation", function()
    it("should compute DJB2 hash", function()
      local content = "test content"
      local hash1 = hot._hash(content)
      local hash2 = hot._hash(content)

      -- Same content should produce same hash
      assert.equals(hash1, hash2)
    end)

    it("should produce different hash for different content", function()
      local hash1 = hot._hash("content 1")
      local hash2 = hot._hash("content 2")

      assert.is_not.equals(hash1, hash2)
    end)
  end)

  describe("file change detection", function()
    it("should detect file change", function()
      local file_path = temp_dir .. "/test.lua"
      TestUtils.write_file(file_path, "version 1")

      local state = {
        scriptPath = file_path,
        hotReloadEnabled = true
      }

      hot.init(state)
      local initial_hash = state._scriptHash

      -- Modify file
      os.execute("sleep 0.1")  -- Ensure timestamp changes
      TestUtils.write_file(file_path, "version 2")

      -- Update should detect change
      local changed = hot.update(state, 1.0)

      assert.is_true(changed)
      assert.is_not.equals(initial_hash, state._scriptHash)
    end)

    it("should not detect change if file unchanged", function()
      local file_path = temp_dir .. "/test.lua"
      TestUtils.write_file(file_path, "version 1")

      local state = {
        scriptPath = file_path,
        hotReloadEnabled = true
      }

      hot.init(state)

      -- Update without changing file
      local changed = hot.update(state, 1.0)

      assert.is_false(changed)
    end)

    it("should respect debounce time", function()
      local file_path = temp_dir .. "/test.lua"
      TestUtils.write_file(file_path, "version 1")

      local state = {
        scriptPath = file_path,
        hotReloadEnabled = true
      }

      hot.init(state)

      -- Immediate update should be debounced
      local changed1 = hot.update(state, 0.01)
      local changed2 = hot.update(state, 0.01)

      -- Second call should be too soon
      assert.is_false(changed2)
    end)
  end)
end)
