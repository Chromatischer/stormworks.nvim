require("utils")
require("helpers")

local counter = 0

function onTick()
  counter = counter + 1
  local doubled = utils.double(counter)
  local result = helpers.format(doubled)
  output.setNumber(1, doubled)
end

function onDraw()
  screen.setColor(255, 255, 255)
  screen.drawText(5, 5, helpers.format(counter))
end
