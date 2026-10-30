local ast = require("calccas.ast")
local calccas = require("calccas")
local parser = require("calccas.parser")
local statement = require("calcnb.statement")

local suite = require("spec.calccas.conformance_cases")

local function rule_of(id)
  return id:match("^(G%-%d%d%a?)")
end

local function dump(src)
  local list = assert(parser.parse_program(src))
  local out, bad = {}, nil
  for _, stmt in ipairs(list) do
    if stmt.node then
      out[#out + 1] = ast.dump(stmt.node)
    else
      bad = bad or stmt.err
    end
  end
  return table.concat(out, " ; "), bad
end

describe("language conformance (grammar.md)", function()
  for _, case in ipairs(suite.cases) do
    it(case.id .. ": " .. (case.src:gsub("%c", " "):sub(1, 40)), function()
      if case.eval then
        local result, err = calccas.evaluate(case.src)
        if type(case.eval) == "table" then
          assert.is_nil(result)
          assert.are.equal(case.eval.error, err.kind)
        else
          assert.is_truthy(result, err and err.message)
          assert.are.equal(case.eval, result.text)
        end
        return
      end
      local text, err = dump(case.src)
      if type(case.expect) == "table" then
        assert.is_truthy(err, "expected an error")
        assert.are.equal(case.expect.error, err.kind)
        assert.is_truthy(err.message:find(case.expect.fragment, 1, true), err.message)
        assert.is_number(err.line)
      else
        assert.is_nil(err, err and err.message)
        assert.are.equal(case.expect, text)
      end
    end)
  end

  it("covers every grammar rule with an accepted case", function()
    local f = assert(io.open("specs/003-expression-language-standard/contracts/grammar.md"))
    local doc = f:read("*a")
    f:close()
    local covered = {}
    for _, case in ipairs(suite.cases) do
      local accepted = case.eval and type(case.eval) == "string"
        or type(case.expect) == "string"
      if accepted then
        covered[rule_of(case.id)] = true
      end
    end
    local missing = {}
    for rule in doc:gmatch("G%-%d%d%a?") do
      if not covered[rule] then
        missing[rule] = true
      end
    end
    local list = {}
    for rule in pairs(missing) do
      list[#list + 1] = rule
    end
    table.sort(list)
    assert.are.same({}, list)
  end)

  it("has a rejected input for every listed rule", function()
    local rejected = {}
    for _, case in ipairs(suite.cases) do
      if type(case.expect) == "table" or type(case.eval) == "table" then
        rejected[rule_of(case.id)] = true
      end
    end
    for _, rule in ipairs(suite.rejects) do
      assert.is_true(rejected[rule], rule)
    end
  end)

  it("uses only grammar rules that exist", function()
    local f = assert(io.open("specs/003-expression-language-standard/contracts/grammar.md"))
    local doc = f:read("*a")
    f:close()
    for _, case in ipairs(suite.cases) do
      assert.is_truthy(doc:find(rule_of(case.id), 1, true), case.id)
    end
  end)
end)

describe("hostile input", function()
  it("lists at least 100 inputs", function()
    assert.is_true(#suite.hostile >= 100)
  end)

  it("never raises a Lua error and never reaches a Lua loader", function()
    _G.__conformance_pwned = nil
    local calls = 0
    local real_load, real_loadstring = _G.load, _G.loadstring
    _G.load = function(...) calls = calls + 1 return real_load(...) end
    _G.loadstring = function(...) calls = calls + 1 return real_loadstring(...) end
    local env = { vars = {}, funcs = {} }
    for _, src in ipairs(suite.hostile) do
      local ok, a, b = pcall(parser.parse, src)
      assert.is_true(ok, "parse raised: " .. tostring(a))
      assert.is_true(a ~= nil or (b ~= nil and b.kind ~= nil), src)
      local pok, perr = pcall(parser.parse_program, src)
      assert.is_true(pok, "parse_program raised: " .. tostring(perr))
      local eok, eerr = pcall(calccas.evaluate, src)
      assert.is_true(eok, "evaluate raised: " .. tostring(eerr))
      local sok, serr = pcall(statement.parse, src, { env = env, lazy = true })
      assert.is_true(sok, "statement.parse raised: " .. tostring(serr))
    end
    _G.load, _G.loadstring = real_load, real_loadstring
    assert.are.equal(0, calls)
    assert.is_nil(_G.__conformance_pwned)
  end)

  it("reports every internal failure as an error value, never `internal`", function()
    for _, src in ipairs(suite.hostile) do
      local _, err = calccas.evaluate(src)
      if err then
        assert.are_not.equal("internal", err.kind, src)
      end
      local list = assert(parser.parse_program(src))
      for _, stmt in ipairs(list) do
        if stmt.err then
          assert.are_not.equal("internal", stmt.err.kind, src)
        end
      end
    end
  end)
end)
