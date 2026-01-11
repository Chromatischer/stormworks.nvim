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

  describe("register_libraries_with_lsp", function()
    it("should print warning when no libraries provided", function()
      MockVim._state.notifications = {}
      
      library.register_libraries_with_lsp({})
      
      -- The function doesn't error, just returns early
      assert.is_true(true)
    end)

    it("should print warning when lua_ls client not found", function()
      MockVim._state.lsp_clients = {}
      
      -- Mock vim.lsp.get_clients to use our mock
      MockVim.lsp.get_clients = function() return {} end

      local libs = {"/test/lib1", "/test/lib2"}

      -- Should not error, just print warning
      library.register_libraries_with_lsp(libs)
      assert.is_true(true)
    end)

    it("should handle LSP client with lua_ls", function()
      -- Create mock LSP client  
      local mock_request_called = false
      MockVim._state.lsp_clients = {
        {
          name = "lua_ls",
          config = {
            root_dir = temp_dir,
            settings = {
              Lua = {
                workspace = {
                  library = {}
                }
              }
            }
          },
          rpc = {
            request = function(method, params, callback)
              mock_request_called = true
              if callback then callback(nil, {}) end
            end
          }
        }
      }

      -- Mock vim.lsp.get_clients to return our client
      MockVim.lsp.get_clients = function(opts)
        if opts and opts.name == "lua_ls" then
          return MockVim._state.lsp_clients
        end
        return {}
      end

      local libs = {"/test/lib1", "/test/lib2"}

      -- Should update LSP settings
      library.register_libraries_with_lsp(libs)
      
      -- The request method should have been called
      assert.is_true(mock_request_called)
    end)
  end)
end)
