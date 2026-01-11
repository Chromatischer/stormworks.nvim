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
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      -- Load main plugin
      local ok, stormworks = pcall(require, "stormworks")

      assert.is_true(ok, "Plugin should load without errors")
      assert.is_table(stormworks)
    end)

    it("should export setup function", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local stormworks = require("stormworks")

      assert.is_function(stormworks.setup)
    end)
  end)

  describe("project detection", function()
    it("should detect microproject in current directory", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local project = require("stormworks.modules.project")

      -- Create .microproject marker
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")

      local detected = project.detect(temp_dir)

      assert.is_not_nil(detected)
      assert.equals(temp_dir, detected)
    end)

    it("should search upward from subdirectory", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local project = require("stormworks.modules.project")

      -- Create nested directory structure
      local sub_dir = temp_dir .. "/src/components"
      os.execute("mkdir -p " .. sub_dir)

      -- Create marker in root
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")

      -- Detect from subdirectory
      local detected = project.detect(sub_dir)

      assert.is_not_nil(detected)
      assert.equals(temp_dir, detected)
    end)
  end)

  describe("library management", function()
    it("should get bundled library paths", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local library = require("stormworks.modules.library")

      local libs = library.get_plugin_libraries()

      assert.is_table(libs)
      assert.is_true(#libs > 0)
    end)

    it("should merge plugin and project libraries", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local library = require("stormworks.modules.library")

      local plugin_libs = {"/plugin/lib1", "/plugin/lib2"}
      local project_libs = {"/project/lib1"}

      local merged = library.merge_libraries(plugin_libs, project_libs)

      assert.equals(3, #merged)
    end)

    it("should deduplicate library paths", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local library = require("stormworks.modules.library")

      local plugin_libs = {"/shared/lib"}
      local project_libs = {"/shared/lib"}

      local merged = library.merge_libraries(plugin_libs, project_libs)

      -- Should not duplicate
      assert.equals(1, #merged)
    end)
  end)

  describe("configuration", function()
    it("should merge user config with defaults", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      local config = require("stormworks.modules.config")

      local user_config = {
        build = {
          minifier = {
            shortenVariables = false
          }
        }
      }

      local merged = config.setup(user_config)

      -- User setting should override
      assert.is_false(merged.build.minifier.shortenVariables)

      -- Default settings should remain
      assert.is_table(merged.love)
      assert.is_table(merged.libraries)
    end)
  end)

  describe("end-to-end workflow", function()
    it("should setup plugin, detect project, and load libraries", function()
      local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
      package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

      -- Create microproject
      local marker_path = temp_dir .. "/.microproject"
      local project_config = [[
return {
  is_microcontroller = true,
  libraries = {"custom_lib"}
}
]]
      TestUtils.write_file(marker_path, project_config)
      MockVim.setFile(marker_path, project_config)

      -- Load modules
      local stormworks = require("stormworks")
      local project = require("stormworks.modules.project")
      local library = require("stormworks.modules.library")

      -- Detect project
      local proj_root = project.detect(temp_dir)
      assert.is_not_nil(proj_root)

      -- Load config
      local proj_config = project.load_config(proj_root)
      assert.is_table(proj_config)
      assert.is_true(proj_config.is_microcontroller)

      -- Get libraries
      local plugin_libs = library.get_plugin_libraries()
      local project_libs = library.get_project_libraries(proj_root, proj_config)
      local all_libs = library.merge_libraries(plugin_libs, project_libs)

      assert.is_table(all_libs)
      assert.is_true(#all_libs > 0)
    end)
  end)
end)
