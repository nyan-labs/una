local get_source_line = require("src.utils.source_line")

local Logger = {}
Logger.__index = Logger

function Logger.new(config)
  local self = config or { name = "logger" }
  self = setmetatable(self, Logger)

  return self
end

local function print(...)
  _G.print(...)
end
local function printf(text, ...)
  _G.print(text:format(...))
end

function Logger:trace(text)
  local file, line = get_source_line()
  printf("%s <trace> at %s:%s: %s", self.name, file, line, text)
end

return Logger
