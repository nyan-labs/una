local DEBUG = os.getenv("DBG") == "1" or false -- oh yeah leftovers, yum

local get_source_line = require "src.utils.source_line"

local function trace(...)
  if DEBUG then
	local file, line = get_source_line()
  
    local concat = ""

    local pack = { n = select("#", ...); ... }

    for i = 1, pack.n, 1 do
      local value = pack[i]

      if value == nil then
        value = "nil"
      end

      value = tostring(value)

      concat = concat .. value
      concat = concat .. (i ~= pack.n and ", " or "")
    end

    print(("%s:%s: %s"):format(file, line, concat))
  end
end

return trace, DEBUG
