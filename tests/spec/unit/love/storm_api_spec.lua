describe("StormAPI", function()
  local MockLove = require("mock_love")
  local TestUtils = require("test_utils")
  local state
  local storm_api

  setup(function()
    -- Install LOVE mock
    _G.love = MockLove

    local project_root = TestUtils.get_project_root()
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    -- Load state first (used by many tests directly)
    state = require("state")
    
    -- Pre-load modules that storm_api will require with the correct names
    -- This allows storm_api to work outside of LÖVE context
    package.loaded['lib.state'] = state
    package.loaded['lib.logger'] = require("logger")
    
    -- Mock canvases module since it requires love.graphics
    package.loaded['lib.canvases'] = {
      withTarget = function(which, fn)
        -- Create a mock API
        local mock_api = {
          clear = function() end,
          setColor = function(r, g, b, a) MockLove.graphics.setColor(r/255, g/255, b/255, (a or 255)/255) end,
          drawRect = function() end,
          drawCircle = function() end,
          drawLine = function() end,
          drawText = function() end,
        }
        fn(mock_api)
      end,
      game = MockLove.graphics.newCanvas(96, 64),
      debug = MockLove.graphics.newCanvas(512, 512),
    }
    
    -- Mock font4x6
    package.loaded['lib.font4x6'] = {
      measureString = function(s) return #s * 4, 6 end
    }
    
    -- Now load storm_api
    storm_api = require("storm_api")
  end)

  before_each(function()
    MockLove.reset()

    -- Reset state
    for i = 1, 32 do
      state.inputB[i] = false
      state.inputN[i] = 0
      state.outputB[i] = false
      state.outputN[i] = 0
    end
  end)

  describe("input", function()
    it("should have input API", function()
      assert.is_table(storm_api.input)
      assert.is_function(storm_api.input.getBool)
      assert.is_function(storm_api.input.getNumber)
    end)

    it("should get boolean input", function()
      state.inputB[1] = true
      state.inputB[2] = false

      assert.is_true(storm_api.input.getBool(1))
      assert.is_false(storm_api.input.getBool(2))
    end)

    it("should get number input", function()
      state.inputN[1] = 0.5
      state.inputN[2] = 0.75

      assert.equals(0.5, storm_api.input.getNumber(1))
      assert.equals(0.75, storm_api.input.getNumber(2))
    end)

    it("should return false for invalid channel", function()
      state.inputB[1] = true

      -- Out of range should return default
      local result = storm_api.input.getBool(0)
      assert.is_false(result)

      result = storm_api.input.getBool(33)
      assert.is_false(result)
    end)
  end)

  describe("output", function()
    it("should have output API", function()
      assert.is_table(storm_api.output)
      assert.is_function(storm_api.output.setBool)
      assert.is_function(storm_api.output.setNumber)
    end)

    it("should set boolean output", function()
      storm_api.output.setBool(1, true)
      storm_api.output.setBool(2, false)

      assert.is_true(state.outputB[1])
      assert.is_false(state.outputB[2])
    end)

    it("should set number output", function()
      storm_api.output.setNumber(1, 0.5)
      storm_api.output.setNumber(2, 0.75)

      assert.equals(0.5, state.outputN[1])
      assert.equals(0.75, state.outputN[2])
    end)
  end)

  describe("property", function()
    it("should have property API", function()
      assert.is_table(storm_api.property)
      assert.is_function(storm_api.property.getNumber)
      assert.is_function(storm_api.property.getText)
      assert.is_function(storm_api.property.getBool)
    end)

    it("should get property number", function()
      state.properties.testNum = 42

      assert.equals(42, storm_api.property.getNumber("testNum"))
    end)

    it("should get property text", function()
      state.properties.testText = "hello"

      assert.equals("hello", storm_api.property.getText("testText"))
    end)
  end)
end)
