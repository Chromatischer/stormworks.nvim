describe("Neovim Plugin Integration", function()
  local MockVim = require("mock_vim")
  local TestUtils = require("test_utils")
  local temp_dir

  setup(function()
    -- Install vim mock
    _G.vim = MockVim
  end)

  before_each(function()
    MockVim.reset()
    temp_dir = TestUtils.create_temp_dir()
    MockVim._state.cwd = temp_dir
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("plugin loading", function()
    it("should load plugin modules without errors", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      -- Load main plugin
      local ok, stormworks = pcall(require, "stormworks")

      assert.is_true(ok, "Plugin should load without errors")
      assert.is_table(stormworks)
    end)

    it("should export setup function", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local stormworks = require("stormworks")

      assert.is_function(stormworks.setup)
    end)
  end)

  describe("project detection", function()
    it("should detect microproject in current directory", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local project = require("stormworks.modules.project")

      -- Create .microproject marker
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")
      MockVim._state.cwd = temp_dir

      local detected_path, marker_type, proj_root = project.detect_micro_project()

      assert.is_not_nil(detected_path)
      assert.equals(temp_dir, proj_root)
    end)

    it("should search upward from subdirectory", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local project = require("stormworks.modules.project")

      -- Create nested directory structure
      local sub_dir = temp_dir .. "/src/components"
      os.execute("mkdir -p " .. sub_dir)

      -- Create marker in root
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")
      MockVim._state.cwd = sub_dir

      -- Detect from subdirectory
      local detected_path, marker_type, proj_root = project.detect_micro_project()

      assert.is_not_nil(detected_path)
      assert.equals(temp_dir, proj_root)
    end)
  end)

  describe("library management", function()
    it("should have register_libraries_with_lsp function", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local library = require("stormworks.modules.library")

      assert.is_function(library.register_libraries_with_lsp)
    end)
  end)

  describe("configuration", function()
    it("should have config table with defaults", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local config = require("stormworks.modules.config")

      -- Config should have nested config table
      assert.is_table(config.config)
      assert.is_table(config.config.project_markers)
      assert.is_table(config.config.keymaps)
    end)

    it("should merge user config via setup", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local config = require("stormworks.modules.config")

      local user_config = {
        build_command = "custom_build"
      }

      config.setup(user_config)

      -- User setting should override
      assert.equals("custom_build", config.config.build_command)
    end)
  end)

  describe("end-to-end workflow", function()
    it("should setup plugin, detect project, and mark as microproject", function()
      local project_root = TestUtils.get_project_root()
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      -- Load modules
      local stormworks = require("stormworks")
      local project = require("stormworks.modules.project")

      MockVim._state.cwd = temp_dir

      -- Mark as microproject
      project.mark_as_micro_project()

      -- Verify marker file was created
      local marker_path = temp_dir .. "/.microproject"
      local content = TestUtils.read_file(marker_path)
      
      assert.is_not_nil(content)
      assert.is_true(content:find("is_microcontroller = true") ~= nil)
    end)
  end)
end)
