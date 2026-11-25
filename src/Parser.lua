local inspect = require("libs.inspect")

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

    -- print("parsing", self.i, self:peek())

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
        return self:make_pos(self:make("variable", identifier.token.value[1], nil), token.pos)
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
    -- print(name)

    self:expect("operator", "{")
    self:advance()

    while not self:is_eof() and not self:check("operator", "}") do
      self:advance()

      -- print("a")
    end

    self:expect("operator", "}")
    self:advance()

    -- print("struct", name)
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

  -- print("primitive: " .. inspect(token))

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
  -- print(success, err)

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

return Parser
