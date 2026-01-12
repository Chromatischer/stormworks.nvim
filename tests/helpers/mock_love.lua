-- Mock LOVE2D framework for unit testing
local MockLove = {}

MockLove.graphics = {
  _canvas = nil,
  _color = {1, 1, 1, 1},
  _draws = {},

  newCanvas = function(w, h, opts)
    return {
      width = w,
      height = h,
      getWidth = function() return w end,
      getHeight = function() return h end,
      getDimensions = function() return w, h end,
      setFilter = function() end,
      newImageData = function()
        return {
          encode = function(_, fmt)
            return { getString = function() return "PNG_DATA" end }
          end,
          getWidth = function() return w end,
          getHeight = function() return h end,
        }
      end
    }
  end,

  setCanvas = function(c) MockLove.graphics._canvas = c end,
  getCanvas = function() return MockLove.graphics._canvas end,
  setColor = function(r, g, b, a)
    MockLove.graphics._color = {r, g, b, a or 1}
  end,
  getColor = function()
    return unpack(MockLove.graphics._color)
  end,
  clear = function()
    MockLove.graphics._draws = {}
  end,
  rectangle = function(mode, x, y, w, h)
    table.insert(MockLove.graphics._draws, {
      type='rect',
      mode=mode,
      x=x, y=y, w=w, h=h,
      color={unpack(MockLove.graphics._color)}
    })
  end,
  circle = function(mode, x, y, r)
    table.insert(MockLove.graphics._draws, {
      type='circle',
      mode=mode,
      x=x, y=y, r=r,
      color={unpack(MockLove.graphics._color)}
    })
  end,
  line = function(x1, y1, x2, y2)
    table.insert(MockLove.graphics._draws, {
      type='line',
      x1=x1, y1=y1, x2=x2, y2=y2,
      color={unpack(MockLove.graphics._color)}
    })
  end,
  print = function(text, x, y)
    table.insert(MockLove.graphics._draws, {
      type='text',
      text=text,
      x=x, y=y,
      color={unpack(MockLove.graphics._color)}
    })
  end,
  draw = function() end,
  newFont = function() return {} end,
  setFont = function() end,
  getFont = function() return {} end,
  setDefaultFilter = function() end,
  setLineStyle = function() end,
  setLineWidth = function() end,
  push = function() end,
  pop = function() end,
  translate = function() end,
  scale = function() end,
  rotate = function() end,
  origin = function() end,
  setScissor = function() end,
  getWidth = function() return 800 end,
  getHeight = function() return 600 end,
  getDimensions = function() return 800, 600 end,
}

MockLove.timer = {
  _time = 0,
  getTime = function() return MockLove.timer._time end,
  getDelta = function() return 1/60 end,
  step = function() MockLove.timer._time = MockLove.timer._time + 1/60 end,
}

MockLove.event = {
  quit = function() end,
  push = function() end,
}

MockLove.filesystem = {
  _files = {},
  getInfo = function(path)
    return MockLove.filesystem._files[path]
  end,
  read = function(path)
    local info = MockLove.filesystem._files[path]
    if info and info.content then
      return info.content
    end
    return nil, "File not found"
  end,
  write = function(path, data)
    MockLove.filesystem._files[path] = {
      type = "file",
      content = data,
      size = #data
    }
    return true
  end,
  createDirectory = function(path)
    MockLove.filesystem._files[path] = {type = "directory"}
    return true
  end,
  setIdentity = function() end,
  getIdentity = function() return "stormworks_test" end,
}

MockLove.image = {
  newImageData = function(w, h, data)
    return {
      getWidth = function() return w or 100 end,
      getHeight = function() return h or 100 end,
      getDimensions = function() return w or 100, h or 100 end,
      encode = function(_, fmt)
        return { getString = function() return "IMAGE_DATA" end }
      end,
    }
  end,
}

MockLove.window = {
  _mode = {800, 600, {}},
  getMode = function() return unpack(MockLove.window._mode) end,
  setMode = function(w, h, flags)
    MockLove.window._mode = {w, h, flags or {}}
    return true
  end,
  setTitle = function() end,
  getTitle = function() return "Test Window" end,
}

MockLove.keyboard = {
  _keys = {},
  isDown = function(key)
    return MockLove.keyboard._keys[key] or false
  end,
  setKeyDown = function(key, down)
    MockLove.keyboard._keys[key] = down
  end,
}

MockLove.mouse = {
  _x = 0,
  _y = 0,
  _buttons = {},
  getPosition = function()
    return MockLove.mouse._x, MockLove.mouse._y
  end,
  setPosition = function(x, y)
    MockLove.mouse._x = x
    MockLove.mouse._y = y
  end,
  isDown = function(button)
    return MockLove.mouse._buttons[button] or false
  end,
  setButtonDown = function(button, down)
    MockLove.mouse._buttons[button] = down
  end,
}

-- Reset all mock state
function MockLove.reset()
  MockLove.graphics._draws = {}
  MockLove.graphics._canvas = nil
  MockLove.graphics._color = {1, 1, 1, 1}
  MockLove.timer._time = 0
  MockLove.filesystem._files = {}
  MockLove.keyboard._keys = {}
  MockLove.mouse._x = 0
  MockLove.mouse._y = 0
  MockLove.mouse._buttons = {}
end

-- Helper to check if specific draw was made
function MockLove.graphics.findDraw(predicate)
  for _, draw in ipairs(MockLove.graphics._draws) do
    if predicate(draw) then
      return draw
    end
  end
  return nil
end

-- Helper to count draws of a type
function MockLove.graphics.countDraws(drawType)
  local count = 0
  for _, draw in ipairs(MockLove.graphics._draws) do
    if draw.type == drawType then
      count = count + 1
    end
  end
  return count
end

return MockLove
