local Tokenizer = {}
Tokenizer.__index = Tokenizer

function Tokenizer.new()
  local self = {}

  setmetatable(self, Tokenizer)

  return self
end

function Tokenizer:tokenize(input)
  local tokens = {}

  self.input = input:gsub("\r\n", "\n")

  self.i = 1

  while not self:is_eof() do
    local min = self.i
    local token = self:parse_token()
    local max = self.i

    local pos = self:position(nil, min, max)

    -- print("tokenizing", self.i, self:peek())

    if token == nil then goto continue end

    table.insert(tokens, {
      token = token,
      pos = pos
    })

    ::continue::
  end

  return tokens
end

function Tokenizer:parse_token()
  local char = self:peek()

  -- only simple comment for now ig
  if char == "-" and self:peek(1) == "-" then
    self:advance()
    self:advance()

    local multiline = false
    local multiline_eq_count = 0
	if self:peek() == "[" then 
	  self:advance()
	  
	  while not self:is_eof() do
	    -- lua got the stupid --[==[equal signs]==]
	    if self:peek() == "=" then 
	      self:advance()

	      multiline_eq_count = multiline_eq_count + 1
	    elseif self:peek() == "[" then
          self:advance()
          
          multiline = true
          break
	    else error("unexpected character " .. self:peek()) end
	  end
	end

	-- todo: make these into comment tokens 
	-- massive fat todo: support comments like `--[[\nstuff\n--]]`, 
    --                   which should at that point become a helper function for strings `local hi = [[hello]]` too
    --                   technically, it works, but it must be completed for the other todo to be complete :D
	if multiline then
	  -- go fuck yourself
      while not self:is_eof() and self:peek() ~= "]" do
        self:advance()
      end

      -- also add -- support
      if self:peek() == "-" and self:peek(1) == "-" and self:peek(2) == "]" then
        self:advance()
        self:advance()
        self:advance()
      elseif self:peek() == "]" then
		self:advance()
      else multiline = false end --
      -- else error("missing closing square bracket for multiline comment") end
    end

    if multiline then
      local eq_count = 0
      while not self:is_eof() and self:peek() ~= "]" do
		if eq_count >= multiline_eq_count then 
          error("too many equal signs, expected " ..  tostring(multiline_eq_count) .. ", got " .. tostring(eq_count))
		end

		self:advance()
	  end

      if self:peek() == "]" then
        self:advance()
      end
	else
	  while not self:is_eof() and self:peek() ~= "\n" do
	    self:advance()
	  end
	end

    return nil
  end


  -- \n is still really important but for right now we ignore it
  if char:match("%s") or char == "\n" then
    self:advance()
    return nil
  end

  -- yes we are doing expr-in-expr, deal with it :3
  if char == [["]] or char == [[']] then
    return self:parse_string()
  end
  -- but what if we want to do .Enum.. hmm
  if char:match("%d") or (char == "." and self:peek(1):match("%d")) then
    return self:parse_number()
  end
  if char:match("%w") then
    return self:parse_identifier()
  end

  return self:parse_operator()
end

Tokenizer.keywords = { "if", "then", "do", "switch", "case", "end", "local", "function", "for", "in", "struct",
  "implement" }
-- yes im aware lookup table is more efficient, its just not worth it
function Tokenizer:parse_identifier()
  local name = ""
  while not self:is_eof() do
    local c = self:peek()

    if not c:match("%w") then break end

    name = name .. c

    self:advance()
  end

  if name == "true" then
    return self:make("boolean", "true")
  end
  if name == "false" then
    return self:make("boolean", "false")
  end

  for _, n in pairs(self.keywords) do
    if n == name then
      return self:make("keyword", name)
    end
  end

  return self:make("identifier", name)
end

-- but wat about hex!! idk
function Tokenizer:parse_number()
  local n = ""
  local has_dot = false
  while not self:is_eof() do
    local c = self:peek()
    -- print("a", c)

    if c == "." then
      if has_dot then
        error("invalid number (extra dot)")
      end

      has_dot = true
    elseif not c:match("%d") then
      break
    end

    n = n .. c
    self:advance()
  end

  return self:make(has_dot and "float" or "int", n)
end

function Tokenizer:parse_string()
  local quote = self:peek()
  self:advance()

  local s = ""

  while not self:is_eof() do
    local c = self:peek()

    -- escaping? who dat!
    if c == quote then
      break
    end

    s = s .. c

    self:advance()
  end

  if self:peek() ~= quote then
    error("unclosed string")
  end

  self:advance()

  return self:make("string", s)
end

Tokenizer.operators = { ":", "=", "{", "}", "(", ")", "." }
-- yes im aware lookup table is more efficient, its just not worth it
function Tokenizer:parse_operator()
  local c = self:peek()

  local found = false
  for _, o in pairs(self.operators) do
    if o == c then
      found = true
    end
  end

  if found then
    self:advance()
    return self:make("operator", c)
  else
    return error("unknown operator " .. c)
  end
end

function Tokenizer:make(type, ...)
  return {
    type = type,
    value = { ... }
  }
end

function Tokenizer:peek(offset)
  offset = offset or 0
  local at = self.i + offset

  local char = self.input:sub(at, at)

  return char
end

function Tokenizer:position(file, min, max)
  return {
    file = file or "???",
    min = min,
    max = max or min
  }
end

function Tokenizer:advance()
  self.i = self.i + 1
end

function Tokenizer:is_eof()
  return self.i > #self.input
end

return Tokenizer
