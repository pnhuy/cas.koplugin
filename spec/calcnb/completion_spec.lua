local completion = require("calcnb.completion")

-- Character positions are 1-based and count UTF-8 characters, as `charpos`
-- does in KOReader's InputText: `dif|` is position 4.
describe("calcnb.completion.word_at", function()
    local function at(text, charpos)
        return completion.word_at(text, charpos)
    end

    it("finds the word ending at the cursor", function()
        local w = at("dif", 4)
        assert.are.equal("dif", w.prefix)
        assert.are.equal(1, w.first)
        assert.are.equal(3, w.last)
        assert.are.equal(1, w.line)
    end)

    it("keeps the text on both sides out of the range", function()
        local w = at("1 + si + 2", 7)
        assert.are.equal("si", w.prefix)
        assert.are.equal(5, w.first)
        assert.are.equal(6, w.last)
    end)

    it("takes the prefix up to the cursor but the range of the whole word", function()
        local w = at("1 + sin + 2", 6)
        assert.are.equal("s", w.prefix)
        assert.are.equal(5, w.first)
        assert.are.equal(7, w.last)
    end)

    it("gives nothing for an empty prefix", function()
        assert.is_nil(at("", 1))
        assert.is_nil(at("x + ", 5))
        assert.is_nil(at("sin", 1))
        assert.is_nil(at("(", 2))
    end)

    it("works at the very end and at the start of a one-letter word", function()
        assert.are.equal("x", at("x", 2).prefix)
        assert.are.equal("x", at("a + x", 6).prefix)
    end)

    it("gives nothing inside a comment", function()
        assert.is_nil(at("# dif", 6))
        assert.is_nil(at("a = 1 # dif", 12))
    end)

    it("still completes before a comment on the same line", function()
        assert.are.equal("di", at("di # note", 3).prefix)
    end)

    it("gives nothing inside a number", function()
        assert.is_nil(at("2e3", 3))
        assert.is_nil(at("2e3", 2))
        assert.is_nil(at("12", 3))
        assert.is_nil(at("2.5e", 5))
        assert.is_nil(at("1 + 3x", 7))
    end)

    it("gives nothing for a name that starts with an underscore", function()
        assert.is_nil(at("_a", 3))
    end)

    it("allows digits and underscores after a first letter", function()
        assert.are.equal("a_1", at("a_1", 4).prefix)
    end)

    it("gives nothing for the range variable of a plot", function()
        assert.is_nil(at("plot(sin(x), x=-1..1)", 15))
        assert.is_nil(at("plot(sin(x), x =-1..1)", 15))
    end)

    it("still completes names elsewhere in a plot call", function()
        assert.are.equal("x", at("plot(sin(x), x", 15).prefix)
        assert.are.equal("s", at("plot(s", 7).prefix)
    end)

    it("completes the left side of an assignment and of ==", function()
        assert.are.equal("x", at("x = 5", 2).prefix)
        assert.are.equal("x", at("(x == 5)", 3).prefix)
    end)

    it("decides on the cursor line only for the cursor line itself", function()
        local w = at("a = 1\ndi", 9)
        assert.are.equal("di", w.prefix)
        assert.are.equal(2, w.line)
        assert.are.equal(7, w.first)
        assert.are.equal(8, w.last)
        assert.is_nil(at("# a note\n", 10))
        assert.are.equal("di", at("# a note\ndi", 12).prefix)
    end)

    it("counts characters, not bytes", function()
        local w = at("π si", 5)
        assert.are.equal("si", w.prefix)
        assert.are.equal(3, w.first)
        assert.are.equal(4, w.last)
        assert.is_nil(at("# π dif", 8))
        assert.are.equal("di", at("# π\ndi", 7).prefix)
    end)

    it("returns nothing for a bad position or text", function()
        assert.is_nil(at("abc", 0))
        assert.is_nil(at("abc", 5))
        assert.is_nil(at("abc", -1))
        assert.is_nil(at("abc", nil))
        assert.is_nil(at("abc", 1.5))
        assert.is_nil(at("abc", "2"))
        assert.is_nil(at(nil, 1))
        assert.is_nil(at(42, 1))
    end)
end)

local function names_of(result)
    local list = {}
    for i, item in ipairs(result.items) do
        list[i] = item.name
    end
    return list
end

describe("calcnb.completion.suggest", function()
    local function suggest(prefix, names, opts)
        return completion.suggest(prefix, names or {}, opts)
    end

    it("offers diff for dif, marked as not available yet", function()
        local r = suggest("dif")
        assert.are.same({ "diff" }, names_of(r))
        local item = r.items[1]
        assert.are.equal("builtin", item.source)
        assert.are.equal("command", item.kind)
        assert.is_false(item.available)
        assert.are.equal("diff()", item.insert)
        assert.are.equal(1, item.back)
        assert.are.equal(0, r.more)
    end)

    it("puts available built-ins before reserved ones", function()
        assert.are.same({ "sin", "sqrt", "simplify", "subs", "solve" }, names_of(suggest("s")))
        assert.are.same({ "sin", "simplify" }, names_of(suggest("si")))
    end)

    it("ranks an exact match first", function()
        assert.are.same({ "pi" }, names_of(suggest("pi")))
        assert.are.same({ "e", "exp", "expand" }, names_of(suggest("e")))
    end)

    it("matches case-insensitively", function()
        assert.are.same({ "sin", "simplify" }, names_of(suggest("SI")))
        assert.are.same({ "sin" }, names_of(suggest("SIN")))
    end)

    it("inserts the bare name for constants and name() for callables", function()
        local pi = suggest("pi").items[1]
        assert.are.equal("constant", pi.kind)
        assert.are.equal("pi", pi.insert)
        assert.are.equal(0, pi.back)
        local sin = suggest("sin").items[1]
        assert.are.equal("function", sin.kind)
        assert.are.equal("sin()", sin.insert)
        assert.are.equal(1, sin.back)
        assert.is_true(sin.available)
        assert.are.equal("command", suggest("plot").items[1].kind)
        assert.are.equal("plot()", suggest("plot").items[1].insert)
    end)

    it("attaches the documentation to built-ins", function()
        local item = suggest("plot").items[1]
        assert.are.equal("plot(f1[, f2, ...], x=lo..hi)", item.doc.signature)
        assert.is_string(item.doc.summary)
        assert.is_table(item.doc.examples)
        assert.is_truthy(suggest("dif").items[1].doc.note:find("reserved", 1, true))
        assert.is_truthy(suggest("ln").items[1].doc.note)
    end)

    it("gives user names no built-in documentation", function()
        local item = suggest("rat", { { name = "rate", kind = "var" } }).items[1]
        assert.are.equal("rate", item.name)
        assert.is_nil(item.doc)
    end)

    it("ranks user names after available built-ins and before reserved ones", function()
        local user = { { name = "sx", kind = "var" }, { name = "sf", kind = "func", params = { "a", "b" } } }
        assert.are.same({ "sin", "sqrt", "simplify", "sf", "sx", "subs", "solve" }, names_of(suggest("s", user, { limit = 10 })))
    end)

    it("gives a function name its parameters and a bracketed template", function()
        local item = suggest("sf", { { name = "sf", kind = "func", params = { "a", "b" } } }).items[1]
        assert.are.same({ "a", "b" }, item.params)
        assert.are.equal("sf()", item.insert)
        assert.are.equal(1, item.back)
        local var = suggest("ra", { { name = "rate", kind = "var" } }).items[1]
        assert.are.equal("rate", var.insert)
        assert.are.equal(0, var.back or 0)
    end)

    it("never offers a name that is not in the list", function()
        assert.are.same({}, suggest("ra", {}).items)
        assert.are.same({}, suggest("ra", { { name = "speed", kind = "var" } }).items)
    end)

    it("offers ln as its own entry", function()
        assert.are.same({ "ln" }, names_of(suggest("ln")))
        assert.are.same({ "log" }, names_of(suggest("lo")))
    end)

    it("limits the list and counts what is left out", function()
        local r = suggest("s", nil, { limit = 2 })
        assert.are.same({ "sin", "sqrt" }, names_of(r))
        assert.are.equal(3, r.more)
        assert.are.equal(0, suggest("s", nil, { limit = 10 }).more)
    end)

    it("defaults to six items", function()
        local names = {}
        for i = 1, 9 do
            names[i] = { name = "sx" .. i, kind = "var" }
        end
        local r = suggest("s", names)
        assert.are.equal(6, #r.items)
        assert.are.equal(14 - 6, r.more)
    end)

    it("returns nothing for an empty or missing prefix or no match", function()
        assert.are.same({}, suggest("").items)
        assert.are.same({}, suggest(nil).items)
        assert.are.same({}, suggest("zzz").items)
        assert.are.equal(0, suggest("zzz").more)
    end)

    it("never raises on odd arguments", function()
        assert.are.same({}, completion.suggest(42, nil, nil).items)
        assert.are.same({ "sin", "simplify" }, names_of(completion.suggest("si", nil, nil)))
        assert.are.same({ "sin" }, names_of(completion.suggest("sin", { 1, "x", {} }, { limit = "many" })))
    end)
end)

describe("calcnb.completion.apply", function()
    local function pick(text, charpos, name)
        local word = completion.word_at(text, charpos)
        local item
        for _, it in ipairs(completion.suggest(word.prefix, {}, { limit = 20 }).items) do
            if it.name == name then
                item = it
            end
        end
        return word, item
    end

    it("turns dif into diff() with the cursor between the brackets", function()
        local word, item = pick("dif", 4, "diff")
        local edit = completion.apply("dif", word, item)
        assert.are.equal("diff()", edit.text)
        assert.are.equal(6, edit.charpos)
        assert.are.equal(1, edit.first)
        assert.are.equal(3, edit.last)
    end)

    it("keeps the text on both sides", function()
        local word, item = pick("1 + si + 2", 7, "sin")
        local edit = completion.apply("1 + si + 2", word, item)
        assert.are.equal("1 + sin() + 2", edit.text)
        assert.are.equal(9, edit.charpos)
    end)

    it("replaces the whole word when the cursor is inside it", function()
        local word, item = pick("1 + sin + 2", 6, "sin")
        local edit = completion.apply("1 + sin + 2", word, item)
        assert.are.equal("1 + sin() + 2", edit.text)
        assert.are.equal(9, edit.charpos)
    end)

    it("puts the cursor after a constant", function()
        local word, item = pick("2 * p", 6, "pi")
        local edit = completion.apply("2 * p", word, item)
        assert.are.equal("2 * pi", edit.text)
        assert.are.equal(7, edit.charpos)
    end)

    it("keeps the other lines byte for byte", function()
        local text = "a = 1\nb = π\nsi\nc = 2"
        local word, item = pick(text, 15, "sin")
        local edit = completion.apply(text, word, item)
        assert.are.equal("a = 1\nb = π\nsin()\nc = 2", edit.text)
        assert.are.equal(17, edit.charpos)
    end)

    it("counts characters when text before the word is not ASCII", function()
        local word, item = pick("π + si", 7, "sin")
        local edit = completion.apply("π + si", word, item)
        assert.are.equal("π + sin()", edit.text)
        assert.are.equal(9, edit.charpos)
    end)

    it("returns nil for a bad word or suggestion", function()
        assert.is_nil(completion.apply("abc", nil, { insert = "x", back = 0 }))
        assert.is_nil(completion.apply("abc", { first = 1, last = 9 }, { insert = "x", back = 0 }))
        assert.is_nil(completion.apply("abc", { first = 1, last = 3 }, nil))
        assert.is_nil(completion.apply(nil, { first = 1, last = 3 }, { insert = "x", back = 0 }))
    end)

    it("leaves the text outside the replaced range unchanged over 200 random edits", function()
        math.randomseed(20260)
        local alphabet = { "a", "s", "si", "sin", "p", "pi", "pl", "di", "dif", "e", "ex", "π", " ", "\n", "(", ")", "+", "1", "#", "é", "=", "x" }
        local checked = 0
        for _ = 1, 200 do
            local parts = {}
            for k = 1, math.random(0, 14) do
                parts[k] = alphabet[math.random(#alphabet)]
            end
            local text = table.concat(parts)
            local chars = {}
            for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                chars[#chars + 1] = ch
            end
            local pos = math.random(1, #chars + 1)
            local word = completion.word_at(text, pos)
            if word then
                local list = completion.suggest(word.prefix, {}, { limit = 20 }).items
                local item = list[math.random(#list)]
                if item then
                    local edit = completion.apply(text, word, item)
                    local head = table.concat(chars, "", 1, word.first - 1)
                    local tail = table.concat(chars, "", word.last + 1, #chars)
                    assert.are.equal(head .. item.insert .. tail, edit.text)
                    assert.are.equal(head, edit.text:sub(1, #head))
                    assert.are.equal(tail, edit.text:sub(#edit.text - #tail + 1))
                    checked = checked + 1
                end
            end
        end
        assert.is_true(checked > 10)
    end)
end)

describe("calcnb.completion_session timing", function()
    -- A Mac figure for the logic alone, not an E Ink figure: the 100 ms budget of
    -- SC-011 is measured on a device. This only catches an accidental blow-up.
    it("updates 1000 times against 100 defined names well inside 5 ms each", function()
        local session = require("calcnb.completion_session").new()
        local names = {}
        for i = 1, 100 do
            names[i] = { name = "sv" .. i, kind = i % 2 == 0 and "func" or "var", params = i % 2 == 0 and { "x" } or nil }
        end
        session:set_names(names)
        local started = os.clock()
        for i = 1, 1000 do
            local text = (i % 2 == 0) and "1 + sv" or "1 + s"
            session:update(text, #text + 1)
        end
        local per_call_ms = (os.clock() - started) * 1000 / 1000
        assert.is_true(per_call_ms < 5, "one update took " .. per_call_ms .. " ms")
    end)
end)
