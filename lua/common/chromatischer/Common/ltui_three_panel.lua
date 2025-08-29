-- Three-panel ltui app (robust tiling using inclusive rects x1,y1,x2,y2)
-- Left: output log
-- Center: square placeholder (reserved for later)
-- Right: toggle controls

local ltui = require("ltui")
local application = ltui.application
local rect = ltui.rect
local window = ltui.window
local button = ltui.button
local textarea = ltui.textarea
local label = ltui.label
local drawable = ltui.drawable.canvas

-- build a rect from x,y and width,height (maps to inclusive x2,y2)
local function rwh(x, y, w, h)
  x = math.floor(x)
  y = math.floor(y)
  w = math.max(1, w)
  h = math.max(1, h)
  w = math.floor(w)
  h = math.floor(h)
  return rect({ x, y, x + w - 1, y + h - 1 })
end

local app = application()

function app:init()
  application.init(self, "three-panel-demo")
  self:background_set("blue")

  local W, H = self:width(), self:height()

  -- usable outer bounds (inclusive), like ltui examples
  local X1, Y1, X2, Y2 = 1, 1, W - 1, H - 1
  local TW = X2 - X1 + 1 -- total width
  local TH = Y2 - Y1 + 1 -- total height

  -- hard mins for ltui windows (conservative)
  local MINW, MINH = 10, 6

  if TW < 3 * MINW or TH < MINH then
    -- Screen is too small for 3 proper windows; show a friendly message
    local full = window:new("window.full", rect({ X1, Y1, X2, Y2 }), "Too small", true)
    self:insert(full)
    local msg = string.format(
      "Terminal too small for 3 windows. Need ~%dx%d, have %dx%d\nResize and retry.",
      3 * MINW,
      MINH,
      TW,
      TH
    )
    local lbl = label:new("lbl.msg", rwh(X1 + 2, Y1 + 2, math.max(10, TW - 4), 2), msg)
    self:insert(lbl)
    return
  end

  -- Start with fixed narrow side panels, center gets remaining space
  local left_w = 50
  local right_w = 20
  local center_w = TW - left_w - right_w
  if center_w < MINW then
    center_w = MINW
  end

  -- center square side is min(remaining width, total height)
  local side = math.min(center_w, TH)

  -- build the three rectangles (non-overlapping, fully inside outer)
  local Lx1, Lx2 = X1, X1 + left_w - 1
  local Rx2 = X2
  local Rx1 = Rx2 - right_w + 1
  local Cx1 = Lx2 + 1
  local Cx2 = Rx1 - 1 -- full width between left and right

  -- vertical for left/right: full height; center: square vertically centered
  local Cy1 = Y1 + math.floor((TH - side) / 2)
  local Cy2 = Cy1 + side - 1

  -- Create windows (short titles reduce width requirements)
  local left_win = window:new("window.left", rect({ Lx1, Y1, Lx2, Y2 }), "Out", true)
  local right_win = window:new("window.right", rect({ Rx1, Y1, Rx2, Y2 }), "Ctrl", true)
  local center_win = window:new("window.center", rect({ Cx1, Cy1, Cx2, Cy2 }), "Canvas", true)

  self:insert(left_win)
  self:insert(right_win)
  self:insert(center_win)

  -- Canvas inside center window
  local canvas_inner_rect = rwh(Cx1 + 1, Cy1 + 1, side - 2, side - 2)
  local main_canvas = drawable:new("canvas.main", canvas_inner_rect, "")
  self:insert(main_canvas)

  -- Draw some lines for testing
  main_canvas:draw_line(1, 1, side - 2, 1) -- horizontal top
  -- main_canvas:draw_line(1, side - 2, side - 2, side - 2) -- horizontal bottom
  -- main_canvas:draw_line(1, 1, 1, side - 2) -- vertical left
  -- main_canvas:draw_line(side - 2, 1, side - 2, side - 2) -- vertical right
  -- main_canvas:draw_line(1, 1, side - 2, side - 2) -- diagonal top-left to bottom-right
  -- main_canvas:draw_line(1, side - 2, side - 2, 1) -- diagonal bottom-left to top-right

  -- Left: output area inside left window (-2 to avoid overhang)
  local left_inner_w = (Lx2 - Lx1) - 2
  local left_inner_h = (Y2 - Y1) - 2
  local log_area = textarea:new(
    "output.log",
    rwh(
      math.floor(Lx1 + 1),
      math.floor(Y1 + 1),
      math.floor(math.max(6, left_inner_w - 2)),
      math.floor(math.max(4, left_inner_h) / 2)
    ),
    ""
  )
  self:insert(log_area)

  local log_lines = {}
  local function log(msg)
    log_lines[#log_lines + 1] = os.date("%H:%M:%S") .. "  " .. msg
    log_area:text_set(table.concat(log_lines, "\n"))
  end

  -- Right: controls inside right window (-2 to avoid overhang)
  local inner_rx1 = Rx1 + 1
  local inner_rw = (Rx2 - Rx1 + 1) - 2
  local row_y = Y1 + 1

  local controls_title =
    label:new("controls.title", rwh(inner_rx1, row_y, math.max(6, inner_rw - 2), 1), "Toggle features:")
  self:insert(controls_title)

  local toggles = {}
  local function make_toggle(name, idx, default)
    toggles[name] = default and true or false
    local function text_for()
      return string.format("[%s] %s", toggles[name] and "x" or " ", name)
    end
    local y = row_y + 1 + (idx - 1) * 3
    local btn = button:new("btn." .. name, rwh(inner_rx1, y, math.max(8, inner_rw - 2), 3), text_for(), function(v)
      toggles[name] = not toggles[name]
      v:text_set(text_for())
      log(string.format("%s -> %s", name, toggles[name] and "ON" or "OFF"))
    end)
    self:insert(btn)
    return btn
  end

  -- Decide how many buttons fit vertically (each ~3 rows after the title)
  local right_inner_h = (Y2 - Y1 + 1) - 2
  local space_after_title = right_inner_h - 1
  local max_buttons = math.max(0, math.floor(space_after_title / 3))

  local names = { "Feature A", "Feature B", "Feature C" }
  for i, n in ipairs(names) do
    if i <= max_buttons then
      make_toggle(n, i, i == 2)
    end
  end

  log(string.format("Layout: W=%d H=%d | L=%d, C=%d, R=%d | TH=%d side=%d", TW, TH, left_w, side, right_w, TH, side))
  log("App started. Ready.")
end

app:run()
