describe("Project", function()
  local MockVim = require("mock_vim")
  local TestUtils = require("test_utils")
  local project
  local temp_dir

  setup(function()
    -- Install vim mock
    _G.vim = MockVim

    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

    project = require("stormworks.modules.project")
  end)

  before_each(function()
    MockVim.reset()
    temp_dir = TestUtils.create_temp_dir()
    MockVim._state.cwd = temp_dir
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("detect_micro_project", function()
    it("should detect .microproject in current directory", function()
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")
      MockVim._state.cwd = temp_dir

      local detected_path, marker_type, project_root = project.detect_micro_project()

      assert.is_not_nil(detected_path)
      assert.equals(".microproject", marker_type)
      assert.equals(temp_dir, project_root)
    end)

    it("should search upward for .microproject", function()
      local sub_dir = temp_dir .. "/src/components"
      os.execute("mkdir -p " .. sub_dir)

      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")
      MockVim._state.cwd = sub_dir

      local detected_path, marker_type, project_root = project.detect_micro_project()

      assert.is_not_nil(detected_path)
      assert.equals(temp_dir, project_root)
    end)

    it("should return nil if no .microproject found", function()
      MockVim._state.cwd = temp_dir

      local detected_path, marker_type, project_root = project.detect_micro_project()

      assert.is_nil(detected_path)
      assert.is_nil(marker_type)
      assert.is_nil(project_root)
    end)

    it("should stop at filesystem root", function()
      MockVim._state.cwd = "/"

      local detected_path, marker_type, project_root = project.detect_micro_project()

      assert.is_nil(detected_path)
    end)
  end)

  describe("mark_as_micro_project", function()
    it("should create .microproject file in current directory", function()
      MockVim._state.cwd = temp_dir

      project.mark_as_micro_project()

      local marker_path = temp_dir .. "/.microproject"
      local content = TestUtils.read_file(marker_path)
      
      assert.is_not_nil(content)
      assert.is_true(content:find("is_microcontroller = true") ~= nil)
    end)
  end)

  describe("get_build_params", function()
    it("should return default build parameters", function()
      -- First set up a project
      local marker_path = temp_dir .. "/.microproject"
      TestUtils.write_file(marker_path, "return {is_microcontroller = true}")
      MockVim.setFile(marker_path, "return {is_microcontroller = true}")
      MockVim._state.cwd = temp_dir

      -- Set current project in config
      local config = require("stormworks.modules.config")
      config.current_project = {
        path = temp_dir,
        marker = ".microproject",
        config = {}
      }

      local params = project.get_build_params({})

      assert.is_table(params)
      assert.equals(true, params.reduceAllWhitespace)
      assert.equals(true, params.removeComments)
    end)

    it("should merge with project-specific settings", function()
      local config = require("stormworks.modules.config")
      config.current_project = {
        path = temp_dir,
        marker = ".microproject",
        config = {}
      }

      local project_config = {
        build_params = {
          shortenVariables = true
        }
      }

      local params = project.get_build_params(project_config)

      assert.equals(true, params.shortenVariables)
      -- Defaults should still exist
      assert.equals(true, params.reduceAllWhitespace)
    end)
  end)
end)
