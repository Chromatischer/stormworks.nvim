local ltui = require("ltui") ---@type ltui
local application = ltui.application ---@type ltui.application
local event = ltui.event ---@type ltui.event
local rect = ltui.rect ---@type ltui.rect
local window = ltui.window ---@type ltui.window
local label = ltui.label ---@type ltui.label
local button = ltui.button ---@type ltui.button
local inputdialog = ltui.inputdialog ---@type ltui.inputdialog
local textarea = ltui.textarea ---@type ltui.textarea
local my_app = application() ---@type ltui.application

function my_app:init()
  application.init(self, "test")
  self:background_set("blue")
  self:insert(window:new("window.sec", rect({ 1, 1, (self:width() - 1) / 2, self:height() }), "secondary window", true))
  self:insert(
    window:new(
      "window.main",
      rect({ (self:width() - 1) / 2, 1, (self:width() - 1) / 2 + (self:width() - 1) / 2, self:height() }),
      "main window",
      true
    )
  )
end

my_app:run()
