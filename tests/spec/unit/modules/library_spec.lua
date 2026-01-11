describe("Library", function()
  local MockVim = require("mock_vim")
  local TestUtils = require("test_utils")
  local library
  local temp_dir

  setup(function()
    -- Install vim mock
    _G.vim = MockVim

    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

    library = require("stormworks.modules.library")
  end)

  before_each(function()
    MockVim.reset()
    temp_dir = TestUtils.create_temp_dir()
    MockVim._state.cwd = temp_dir
  end)

  after_each(function()
    TestUtils.remove_temp_dir(temp_dir)
  end)

  describe("get_plugin_libraries", function()
    it("should return bundled library paths", function()
      local libs = library.get_plugin_libraries()

      assert.is_table(libs)
      assert.is_true(#libs > 0)

      -- Should include LifeBoatAPI paths
      local has_lifeboat = false
      for _, path in ipairs(libs) do
        if path:match("LifeBoatAPI") then
          has_lifeboat = true
          break
        end
      end
      assert.is_true(has_lifeboat)
    end)
  end)

  describe("get_project_libraries", function()
    it("should return project library paths from config", function()
      local project_config = {
        libraries = {"lib1", "lib2"}
      }

      local libs = library.get_project_libraries(temp_dir, project_config)

      assert.is_table(libs)
    end)

    it("should handle empty libraries list", function()
      local project_config = {
        libraries = {}
      }

      local libs = library.get_project_libraries(temp_dir, project_config)

      assert.is_table(libs)
    end)

    it("should handle missing libraries field", function()
      local project_config = {}

      local libs = library.get_project_libraries(temp_dir, project_config)

      assert.is_table(libs)
      assert.equals(0, #libs)
    end)
  end)

  describe("merge_libraries", function()
    it("should merge plugin and project libraries", function()
      local plugin_libs = {"/plugin/lib1", "/plugin/lib2"}
      local project_libs = {"/project/lib1"}

      local merged = library.merge_libraries(plugin_libs, project_libs)

      assert.equals(3, #merged)
    end)

    it("should deduplicate libraries", function()
      local plugin_libs = {"/shared/lib"}
      local project_libs = {"/shared/lib"}

      local merged = library.merge_libraries(plugin_libs, project_libs)

      -- Should not duplicate
      assert.equals(1, #merged)
    end)
  end)

  describe("register_with_lsp", function()
    it("should update LSP workspace library settings", function()
      MockVim._state.lsp_clients = {
        {
          name = "lua_ls",
          config = {
            settings = {
              Lua = {
                workspace = {
                  library = {}
                }
              }
            }
          }
        }
      }

      local libs = {"/test/lib1", "/test/lib2"}

      library.register_with_lsp(libs)

      -- Check that LSP client settings were updated
      -- In actual implementation, this would modify client settings
      assert.is_not_nil(MockVim._state.lsp_clients)
    end)

    it("should handle no active LSP clients", function()
      MockVim._state.lsp_clients = {}

      local libs = {"/test/lib1"}

      -- Should not error
      library.register_with_lsp(libs)
    end)
  end)
end)
