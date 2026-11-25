local inspect = require("libs.inspect")

local Tokenizer = require("src.Tokenizer")
local Parser = require("src.Parser")

local Flags = require("src.utils.Flags")
local Logger = require("src.utils.Logger")

-- util
local function file_or_string(s)
  local f = io.open(s, "rb")
  if f then 
    s = f:read "*a"
    f:close()
  end

  return s
end
--

local Una = {}
Una.__index = Una

Una.version = "1.0.0-alpha"

Una.logger = Logger.new { name = "una" }

Una.flags = Flags {
  {"-v", "--version"}
}

function Una.new()
  return setmetatable({}, Una)
end

function Una:tokenize(input)
  local tokenizer = Tokenizer.new()
  local tokens = tokenizer:tokenize(input)

  -- use and dispose
  tokenizer = nil
	
  return tokens
end

function Una:parse(tokens)
  if type(tokens) == "string" then
	tokens = self:tokenize(tokens)
  elseif type(tokens) ~= "table" then
	error("can't parse type `" .. type(tokens) .. "`, must be either `string` or `table` (tokens)")
  end
  
  local parser = Parser.new()
  local exprs = parser:parse(tokens)

  -- again use and dispose lol
  parser = nil

  return exprs
end

function Una:main(arg)
  local args = {unpack(arg, 1, #arg)}

  local rest = {}

  for _, arg in pairs(args) do
  	local key, value = arg:match "^(%-?%-[_%-%.%w]+)%=?([_%-%.%w]-)$"
	if key == nil then
	  table.insert(rest, arg)
	  goto continue
	end

    value = value:gsub("(%s+)", "")
    if value == "" or value == "1" or value == "true" then
      value = true
   	elseif value == "0" or value == "false" then
      value = false
    end

	self.flags:set(key, value)

  	::continue::
  end

  if self.flags["--version"] then
    -- i chose ⠥ because its u in braille lol
    print(("⠥ una %s"):format(self.version))
	return
  end
   
  local input = file_or_string(rest[1] or error("empty input text/file"))

  local exprs = self:parse(input)
  print(inspect(exprs))
end

return Una
