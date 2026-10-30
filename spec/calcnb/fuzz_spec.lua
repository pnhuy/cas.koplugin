local notebook = require("calcnb.notebook")

-- Hostile or malformed cell sources (SC-006): each must come back as an
-- output, never as a raised error, and never as executed Lua.
local HOSTILE = {
    "", " ", "\n\n\n", "(", ")", "((((((((((", "))))))))))", "1 +", "+ 1", "1 + + 1", "1 */ 2", "x =", "= 5",
    "f(x) =", "f(x) = f(x)", "a = a", "a = b\nb = a", "1/0", "0/0", "0^0", "(-1)^(1/2)", "sqrt(-1)", "ln(0)", "ln(-1)",
    "10^1000", "10^(10^10)", "9^9^9^9", "factorial(1000)", "sin(", "sin()", "sin(,)", "sin(1,2,3)", "nofunc(1)", "x y z",
    "1..2", "1.2.3", "1e", "1e+", "--1", "!!", "@#$%^&", "\\", "'", "\"", "`", "os.execute('x')", "io.popen('x')",
    "require('os')", "load('return 1')", "dofile('x')", "_G", "print(1)", "while true do end", "function() end",
    "return 1", "end", "[[", "--[[", "--", string.rep("(", 500), string.rep(")", 500), string.rep("1+", 500) .. "1",
    string.rep("x", 5000), string.rep("sin(", 200) .. "1" .. string.rep(")", 200), string.rep("a=1\n", 300),
    "plot(", "plot()", "plot(1,2,3,4,5,6,7,8,9,10)", "plot(sin(x), x=1..0)", "plot(sin(x), x=a..b)", "plot(1/0)",
    "plot(x, x=-1e300..1e300)", "é", "∞", "π", "x²", "\0", "\1\2\3", "a\0b", "1\r\n2", "1\t+\t2",
}

describe("calcnb.runner on hostile input", function()
    for i, source in ipairs(HOSTILE) do
        it("source " .. i .. " does not raise", function()
            local nb = notebook.new("T")
            local id = nb.cells[1].id
            nb:set_source(id, source) -- may refuse (encoding, limit); the cell then keeps its old text
            local ok, err = pcall(nb.run_cell, nb, id)
            assert.is_true(ok, tostring(err))
            local cell = nb.cells[1]
            assert.is_true(cell.status == "completed" or cell.status == "error" or cell.status == "idle")
        end)
    end

    it("raw invalid UTF-8 is refused by the cell", function()
        local nb = notebook.new("T")
        local ok, err = nb.set_source(nb, nb.cells[1].id, "bad\xff")
        assert.is_nil(ok)
        assert.are.equal("encoding", err.kind)
    end)

    it("covers at least 50 cases", function()
        assert.is_true(#HOSTILE >= 50)
    end)

    it("a failing cell leaves the environment usable", function()
        local nb = notebook.new("T")
        local first = nb.cells[1]
        local second = assert(nb:add(2))
        nb:set_source(first.id, "a = 2\nb = (")
        nb:run_cell(first.id)
        nb:set_source(second.id, "1 + 1")
        local out = nb:run_cell(second.id)
        assert.are.equal("2", out.canonical)
    end)
end)

describe("typing never evaluates", function()
    it("200 edits leave the cell idle with no output", function()
        local nb = notebook.new("T")
        local id = nb.cells[1].id
        local text = ""
        for i = 1, 200 do
            text = text .. string.char(97 + i % 26)
            assert(nb:set_source(id, text))
        end
        local cell = nb.cells[1]
        assert.are.equal("idle", cell.status)
        assert.is_nil(cell.output)
        assert.are.equal(0, nb.exec_counter)
    end)
end)

describe("input never reaches a Lua loader or the system", function()
    local runner = require("calcnb.runner")
    local env_mod = require("calcnb.env")
    local suite = require("spec.calccas.conformance_cases")

    local PIECES = {
        "1", "2.5", "1e3", "1e-3", "x", "y", "f", "pi", "e", "sin(", "plot(", "diff(", "(", ")", ",", "+", "-", "*", "/", "^",
        "=", "==", "..", "#", "\n", " ", "x=-5..5", "f(x) = ", "os.execute(", "load(", "$", "2x", "1e999",
    }

    it("calls none of load, loadstring, dofile, require, os.execute or io.open over 200 edits and the hostile list", function()
        runner.run("1", env_mod.new()) -- load every module before the stubs go in
        runner.run("plot(sin(x))", env_mod.new())
        local names = { "load", "loadstring", "dofile", "require" }
        local saved, calls = {}, 0
        local function stub()
            calls = calls + 1
            error("forbidden call from user input")
        end
        for _, name in ipairs(names) do
            saved[name] = _G[name]
            _G[name] = stub
        end
        local function set(tbl, key, value)
            tbl[key] = value
        end
        local real_execute, real_open = os.execute, io.open
        set(os, "execute", stub)
        set(io, "open", stub)

        local ok, err = pcall(function()
            math.randomseed(2026)
            local text = ""
            for _ = 1, 200 do
                local op = math.random(3)
                if op == 1 or #text == 0 then
                    text = text .. PIECES[math.random(#PIECES)]
                elseif op == 2 then
                    local cut = math.random(#text)
                    text = text:sub(1, cut - 1) .. text:sub(cut + 1)
                else
                    text = PIECES[math.random(#PIECES)] .. text
                end
                if not runner.run(text, env_mod.new()) then
                    error("no output for " .. text)
                end
            end
            for _, src in ipairs(suite.hostile) do
                if not runner.run(src, env_mod.new()) then
                    error("no output for " .. src)
                end
            end
        end)

        for _, name in ipairs(names) do
            _G[name] = saved[name]
        end
        set(os, "execute", real_execute)
        set(io, "open", real_open)
        assert.is_true(ok, tostring(err))
        assert.are.equal(0, calls)
    end)
end)
