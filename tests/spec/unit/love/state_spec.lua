describe("State", function()
  local MockLove = require("mock_love")
  local state

  setup(function()
    -- Install LOVE mock
    _G.love = MockLove

    -- Load state module (this returns the state table directly)
    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    state = require("state")
  end)

  before_each(function()
    MockLove.reset()
  end)

  describe("initialization", function()
    it("should initialize 32 boolean input channels", function()
      assert.is_table(state.inputB)
      assert.equals(32, #state.inputB)

      for i = 1, 32 do
        assert.is_boolean(state.inputB[i])
      end
    end)

    it("should initialize 32 number input channels", function()
      assert.is_table(state.inputN)
      assert.equals(32, #state.inputN)

      for i = 1, 32 do
        assert.is_number(state.inputN[i])
      end
    end)

    it("should initialize 32 boolean output channels", function()
      assert.is_table(state.outputB)
      assert.equals(32, #state.outputB)
    end)

    it("should initialize 32 number output channels", function()
      assert.is_table(state.outputN)
      assert.equals(32, #state.outputN)
    end)

    it("should have default tick rate", function()
      assert.is_number(state.tickRate)
      assert.is_true(state.tickRate > 0)
    end)

    it("should have running state", function()
      assert.is_boolean(state.running)
    end)

    it("should have simulator driven tracking", function()
      assert.is_table(state.simulatorDriven)
      assert.is_table(state.simulatorDriven.inputB)
      assert.is_table(state.simulatorDriven.inputN)
    end)
  end)

  describe("getGameSize", function()
    it("should calculate game canvas size from tiles", function()
      state.tilesX = 3
      state.tilesY = 2
      state.tileSize = 32

      local w, h = state.getGameSize()

      assert.equals(96, w)  -- 3 * 32
      assert.equals(64, h)  -- 2 * 32
    end)
  end)
end)
