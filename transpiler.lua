-- hi! this is merely a prototype, if it goes well,
-- then i will selfhost this and then rewrite it in that language
-- (as of writing, i dont really know what to name this LOL)

local inspect = require "libs.inspect"

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

    print("tokenizing", self.i, self:peek())

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

	while not self:is_eof() and self:peek() ~= "\n" do
	  self:advance()
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
    print("a", c)

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

-- parser
local Parser = {}
Parser.__index = Parser

function Parser.new()
  local self = {}

  setmetatable(self, Parser)

  return self
end

function Parser:parse(tokens)
  self.tokens = tokens
  self.i = 1

  local exprs = {}

  while not self:is_eof() do
    local expr = self:parse_expression()

    print("parsing", self.i, self:peek())

    if expr == nil then goto continue end

    table.insert(exprs, expr)

    ::continue::
  end

  return exprs
end

function Parser:parse_expression()
  -- local token = self:peek()
  --
  --   self:advance()
  --
  --   return {
  --     expr = token.token,
  --     pos = token.pos
  -- }

  local token = self:peek()

  -- wat about postfix? smh. we gotta do parse_expr() -> parse_postfix() -> parse_primitive -> etc...
  --   if self:check("string") then
  --     self:advance()
  --     return self:make_pos(self:make("string", token.token.value[1]), token.pos)
  --   end
  --   if self:check("int") then
  --     self:advance()
  --     return self:make_pos(self:make("int", token.token.value[1]), token.pos)
  --   end
  --   if self:check("float") then
  --     self:advance()
  --     return self:make_pos(self:make("float", token.token.value[1]), token.pos)
  --   end
  --   if self:check("boolean") then
  --     self:advance()
  --     return self:make_pos(self:make("boolean", token.token.value[1]), token.pos)
  --   end
  --
  --   if self:check("identifier") and self.check(self:peek(1), "operator", "=") then
  --     self:advance()
  --     self:advance()
  --
  --     local expr = self:parse_expression()
  --
  -- 	return self:make_pos(self:make("assign", token.token.value[1], expr))
  --   end

  if self:check("keyword", "local") then
    self:advance()

    local identifier = self:peek()
    if identifier.token.type ~= "identifier" then error("expected identifier, got " .. identifier.token.type) end
    self:advance()

    -- rn its stupid shhh
    local type = "Dynamic"
    if self:check("operator", ":") then
      self:advance()

      self:expect("identifier")
      type = self:peek().token.value[1]
      self:advance()
    end

    if not self:check("operator", "=") then
      error("expected equal sign, got sm bs")
    end
    self:advance()

    local value = self:parse_expression()

    return self:make_pos(self:make("variable", identifier.token.value[1], value), token.pos)
  end

  if self:check("keyword", "if") then
    self:advance()

    -- hmm.. do we also let rust-like extractor patterns in here?
    local condition = self:parse_expression()

    self:expect("keyword", "then")
    self:advance()

    local block = self:parse_block()

    return self:make_pos(self:make("if", block), token.pos) -- idk idc, the pos is incorrect but i dont care much
  end

  if self:check("keyword", "struct") then
    self:advance()

    local name = self:expect_identifier()
    print(name)

    self:expect("operator", "{")
    self:advance()

    while not self:is_eof() and not self:check("operator", "}") do
      self:advance()

      print("a")
    end

    self:expect("operator", "}")
    self:advance()

    print("struct", name)
    return self:make_pos(self:make("struct", name, {}), token.pos)
  end

  return self:parse_postfix()

  --   error("unparsed token " .. tostring(token) .. "; " .. tostring(token.token.type) .. "; " .. table.concat(token.token.value, ";") .. "; at " .. tostring(token.pos.min))
  --
  --   return nil
end

function Parser:parse_postfix()
  local expr = self:parse_primitive()

  if expr == nil then
    return nil
  end


  if self:check("operator", "=") then
    self:advance()

    local value = self:parse_expression()

    return self:make_pos(self:make("binop", expr, "assign", value))
  end

  if self:check("operator", "{") then
    self:advance()

    -- todo

    self:expect("operator", "}")
    self:advance()

    return self:make_pos(self:make("binop", expr, "construct", {}))
  end

  if self:check("operator", ":") then
    self:advance()

    local name = self:parse_postfix()

    return self:make_pos(self:make("binop", expr, "self_call?", name))
  end

  if self:check("operator", "(") then
    self:advance()

    --todo

    self:expect("operator", ")")
    self:advance()

    return self:make_pos(self:make("binop", expr, "call", nil))
  end

  return expr
end

function Parser:parse_primitive()
  local token = self:peek()

  print("primitive: " .. inspect(token))

  if self:check("string") then
    self:advance()
    return self:make_pos(self:make("const", self:make("string", token.token.value[1]), token.pos))
  end
  if self:check("int") then
    self:advance()
    return self:make_pos(self:make("const", self:make("int", token.token.value[1]), token.pos))
  end
  if self:check("float") then
    self:advance()
    return self:make_pos(self:make("const", self:make("float", token.token.value[1]), token.pos))
  end
  if self:check("boolean") then
    self:advance()
    return self:make_pos(self:make("const", self:make("boolean", token.token.value[1]), token.pos))
  end
  if self:check("identifier") then
    self:advance()
    return self:make_pos(self:make("const", self:make("identifier", token.token.value[1]), token.pos))
  end

  error("unparsed token " .. inspect(token))
end

function Parser:parse_block()
  local exprs = {}

  local pos_start = self:peek(-1).pos

  while not self:is_eof() or self:check("keyword", "end") do
    local expr = self:parse_expression()

    table.insert(exprs, expr)
  end

  local pos_end = self:peek().pos

  local pos = {
    file = pos_start.file,
    min = pos_start.min,
    max = pos_end.max
  }

  return self:make_pos(self:make("block", exprs), pos)
end

function Parser:expect_identifier()
  self:expect("identifier")
  local name = self:peek().token.value[1]
  self:advance()
  return name
end

function Parser:make(type, ...)
  return {
    type = type,
    value = { ... }
  }
end

function Parser:make_pos(expr, pos)
  return {
    expr = expr,
    pos = pos
  }
end

function Parser:check(type, ...)
  local token = self.token ~= nil and self or self:peek()

  --print(token.token.type, token.token.value[1], type, table.concat({...}, "; "))

  local success, err = pcall(Parser.expect, token, type, ...)
  print(success, err)

  return success
end

function Parser:expect(type, ...)
  -- basically lets you do self.check(self:peek(25), "string") or self:check("string")
  local token = self.token ~= nil and self or self:peek()

  local values = { ... }

  if type ~= token.token.type then error("expected type " .. type .. ", got " .. token.token.type) end
  for i, value in ipairs(values) do
    -- if we have a nil passed then we're not gonna check it at all, basically skip
    if value == nil then goto continue end

    if value ~= token.token.value[i] then error("expected value " ..
      value .. ", got " .. tostring(token.token.value[i]) .. ", at " .. i) end

    ::continue::
  end
end

function Parser:peek(offset)
  offset = offset or 0
  local at = self.i + offset
  --print("accessing at " .. self.input:sub(at, at + 5) .. " (" .. at .. ")")

  local token = self.tokens[at]

  return token
end

function Parser:advance()
  self.i = self.i + 1
end

function Parser:is_eof(i)
  return i or self.i > #self.tokens
end

--
_G.arg = _G.arg or {...}

local input = arg[1]
local f = io.open(input, "rb")
if f then 
  input = f:read "*a"
  f:close()
end
print("parsing " .. input)
  
local tokenizer = Tokenizer.new()
local tokens = tokenizer:tokenize(input)

print("congrats on tokenizing!:")
print(inspect(tokens))
print "\n\n\n\n"

local parser = Parser.new()
local exprs = parser:parse(tokens)

print("congrats on parsing!:")
-- for i, e in ipairs(exprs) do
--   print(i, e.pos.min, e.pos.max, e.expr.type, inspect(e.expr.value))
-- end
print(inspect(exprs, { indent = "  " }))
