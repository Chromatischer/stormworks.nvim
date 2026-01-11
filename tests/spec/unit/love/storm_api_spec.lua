describe("StormAPI", function()
  local MockLove = require("mock_love")
  local state

  setup(function()
    -- Install LOVE mock
    _G.love = MockLove

    local project_root = os.getenv("STORMWORKS_PROJECT_ROOT") or "/home/god/Stormworks/stormworks.nvim"
    package.path = project_root .. "/lua/stormworks/common/chromatischer/Love/lib/?.lua;" .. package.path

    -- Load state first
    state = require("state")
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
    it("should create input API", function()
      local storm_api = require("storm_api")
      local input_api = storm_api.createInputAPI(state)

      assert.is_function(input_api.getBool)
      assert.is_function(input_api.getNumber)
    end)

    it("should get boolean input", function()
      local storm_api = require("storm_api")
      local input_api = storm_api.createInputAPI(state)

      state.inputB[1] = true
      state.inputB[2] = false

      assert.is_true(input_api.getBool(1))
      assert.is_false(input_api.getBool(2))
    end)

    it("should get number input", function()
      local storm_api = require("storm_api")
      local input_api = storm_api.createInputAPI(state)

      state.inputN[1] = 0.5
      state.inputN[2] = 0.75

      assert.equals(0.5, input_api.getNumber(1))
      assert.equals(0.75, input_api.getNumber(2))
    end)

    it("should clamp channel to valid range", function()
      local storm_api = require("storm_api")
      local input_api = storm_api.createInputAPI(state)

      state.inputB[1] = true

      -- Out of range should clamp to valid range
      local result = input_api.getBool(0)  -- Should clamp to 1
      assert.is_boolean(result)

      result = input_api.getBool(33)  -- Should clamp to 32
      assert.is_boolean(result)
    end)
  end)

  describe("output", function()
    it("should create output API", function()
      local storm_api = require("storm_api")
      local output_api = storm_api.createOutputAPI(state)

      assert.is_function(output_api.setBool)
      assert.is_function(output_api.setNumber)
    end)

    it("should set boolean output", function()
      local storm_api = require("storm_api")
      local output_api = storm_api.createOutputAPI(state)

      output_api.setBool(1, true)
      output_api.setBool(2, false)

      assert.is_true(state.outputB[1])
      assert.is_false(state.outputB[2])
    end)

    it("should set number output", function()
      local storm_api = require("storm_api")
      local output_api = storm_api.createOutputAPI(state)

      output_api.setNumber(1, 0.5)
      output_api.setNumber(2, 0.75)

      assert.equals(0.5, state.outputN[1])
      assert.equals(0.75, state.outputN[2])
    end)
  end)

  describe("screen", function()
    it("should create screen API", function()
      local storm_api = require("storm_api")
      local screen_api = storm_api.createScreenAPI(state, "game")

      assert.is_function(screen_api.setColor)
      assert.is_function(screen_api.drawRect)
      assert.is_function(screen_api.drawCircle)
      assert.is_function(screen_api.drawLine)
      assert.is_function(screen_api.drawText)
    end)

    it("should convert color from 0-255 to 0-1", function()
      local storm_api = require("storm_api")
      local screen_api = storm_api.createScreenAPI(state, "game")

      screen_api.setColor(255, 128, 0, 255)

      -- Check that love.graphics.setColor was called
      local r, g, b, a = MockLove.graphics.getColor()
      assert.equals(1, r)
      assert.is_true(g > 0.49 and g < 0.51)  -- ~0.5
      assert.equals(0, b)
      assert.equals(1, a)
    end)
  end)
end)
