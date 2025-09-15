-- Stormworks LÖVE debug-canvas API stubs
-- Provides the `dbg` table with drawing helpers that target the debug canvas
-- Used for editor IntelliSense and diagnostics only; no runtime behavior here.

--- @diagnostic disable: lowercase-global

--- Debug draw API. Draws onto the debug canvas provided by the LÖVE runner.
--- All functions are no-ops in this stub and are here to satisfy tooling.
dbg = {}

--- Set current debug draw color
--- @param r integer 0-255
--- @param g integer 0-255
--- @param b integer 0-255
--- @param a integer|nil 0-255 (default 255)
function dbg.setColor(r, g, b, a) end

--- Set line width for subsequent debug lines/rects/circles
--- @param w number
function dbg.setLineWidth(w) end

--- Draw outlined rectangle on debug canvas
--- @param x number
--- @param y number
--- @param width number
--- @param height number
function dbg.drawRect(x, y, width, height) end

--- Draw filled rectangle on debug canvas
--- @param x number
--- @param y number
--- @param width number
--- @param height number
function dbg.drawRectF(x, y, width, height) end

--- Draw outlined circle on debug canvas
--- @param x number center x
--- @param y number center y
--- @param radius number
function dbg.drawCircle(x, y, radius) end

--- Draw filled circle on debug canvas
--- @param x number center x
--- @param y number center y
--- @param radius number
function dbg.drawCircleF(x, y, radius) end

--- Draw a line on debug canvas
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
function dbg.drawLine(x1, y1, x2, y2) end

--- Draw text on debug canvas
--- @param x number
--- @param y number
--- @param text string
function dbg.drawText(x, y, text) end

--- Get debug canvas width in pixels
--- @return number width
function dbg.getWidth() end

--- Get debug canvas height in pixels
--- @return number height
function dbg.getHeight() end

--- Clear debug canvas with optional color
--- @param r integer|nil 0-255 (default 0)
--- @param g integer|nil 0-255 (default 0)
--- @param b integer|nil 0-255 (default 0)
--- @param a integer|nil 0-255 (default 255)
function dbg.clear(r, g, b, a) end
