local Flags = {}

function Flags.new(flags)
  local self = {}
  for i, keys in pairs(flags) do
	if type(i) == "table" then
      self[i] = keys
	else
	  self[keys] = false
    end
  end
   
  self = setmetatable(self, Flags)
  return self
end
Flags.__call = function(_, t) return Flags.new(t) end

function Flags:get(key)
  for keys, flag in pairs(self) do
    for _, k in pairs(keys) do
      if k ~= key then goto continue end

      do return flag end -- wtf lua?!
      ::continue::
    end
  end

  return nil
end
function Flags:__index(key)
  local value = rawget(Flags, key)

  if not value then value = self:get(key) end
  
  return value
end

function Flags:set(key, value)
  for keys, flag in pairs(self) do
    for i, k in pairs(keys) do
      if type(key) == "table" then
        if k ~= key[i] then goto continue end
      else
      	if k ~= key then goto continue end
      end

      rawset(self, keys, value)
      do return true end -- again, wtf
      ::continue::
    end
  end

  if type(key) == "table" then
    rawset(self, key, value)
  else
    rawset(self, {key}, value)
  end
  return false
end
Flags.__newindex = Flags.set

function Flags:__tostring()
  local flags = {}

  for keys, flag in pairs(self) do
  	local name = table.concat(keys, ", ")

  	table.insert(flags, ("%s: %s"):format(name, flag))
  end

  local s = "Flags {"
  
  for i, f in ipairs(flags) do
	s = s .. "\n  " .. f .. (i ~= #flags and "," or "")
  end

  s = s .. "\n}"

  return s
end

return setmetatable(Flags, Flags)
