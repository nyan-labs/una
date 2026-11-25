local function get_source_line(depth)
  local caller = debug.getinfo((depth or 0) + 3)
  local file, line = caller.short_src, caller.currentline

  return file, line
end

return get_source_line
