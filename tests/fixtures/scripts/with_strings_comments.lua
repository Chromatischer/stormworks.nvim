-- This is a comment that should be removed
local s1 = "hello -- not a comment"
local s2 = 'single quotes "nested"'
local s3 = [[
multiline string
with -- comments
inside
]]

--[[ This is a
multi-line
comment ]]

function onTick()
  -- Another comment
  output.setNumber(1, #s1)
end
