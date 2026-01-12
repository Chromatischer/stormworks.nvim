helpers = {}

function helpers.format(n)
  return "Value: " .. tostring(n)
end

function helpers.clamp(n, min, max)
  if n < min then return min end
  if n > max then return max end
  return n
end
