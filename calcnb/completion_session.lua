-- State of the suggestion strip for one editor: what is shown, which item is
-- highlighted, and which word was dismissed. Pure Lua; the view feeds it the
-- text and cursor after every edit and draws `model()`. Nothing here runs or
-- saves anything.

local completion = require("calcnb.completion")

local M = {}

local Session = {}
Session.__index = Session

-- `opts.suggest` replaces `completion.suggest` (a test seam).
function M.new(opts)
    return setmetatable({
        names = {},
        limit = nil,
        suggest = opts and opts.suggest or completion.suggest,
        shown = nil, -- { items, more, highlight }
        word = nil,
        text = nil,
        prefix = nil,
        dismissed = nil, -- { first, line } of the word the user dismissed
    }, Session)
end

function Session:set_names(names)
    self.names = type(names) == "table" and names or {}
end

function Session:set_limit(limit)
    self.limit = limit
end

local function same_word(a, b)
    return a and b and a.first == b.first and a.line == b.line
end

-- A comparable summary of what the strip would draw.
local function signature(shown)
    if not shown then
        return ""
    end
    local parts = {}
    for i, item in ipairs(shown.items) do
        parts[i] = item.name
    end
    return table.concat(parts, ";") .. "|" .. shown.highlight .. "|" .. shown.more
end

local function recompute(self, text, charpos)
    local word = completion.word_at(text, charpos)
    self.text, self.word = text, word
    if not word then
        self.dismissed, self.prefix = nil, nil
        return nil
    end
    if self.dismissed and not same_word(self.dismissed, word) then
        self.dismissed = nil
    end
    if self.dismissed then
        return nil
    end
    local found = self.suggest(word.prefix, self.names, { limit = self.limit })
    if #found.items == 0 then
        self.prefix = nil
        return nil
    end
    local highlight = 1
    if self.shown and self.prefix == word.prefix and same_word(self.shown.word, word) then
        highlight = math.min(self.shown.highlight, #found.items)
    end
    self.prefix = word.prefix
    return { items = found.items, more = found.more, highlight = highlight, word = word }
end

-- Recomputes from the current text and cursor. Returns true only when what
-- the strip draws changed. A failure hides the strip instead of raising.
function Session:update(text, charpos)
    local before = signature(self.shown)
    local ok, shown = pcall(recompute, self, text, charpos)
    if not ok then
        shown = nil
        self.word, self.prefix = nil, nil
    end
    self.shown = shown
    return signature(shown) ~= before
end

-- `{ items, more, highlight }`, or nil when the strip is hidden.
function Session:model()
    return self.shown
end

function Session:select(index)
    local shown = self.shown
    if not shown or type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #shown.items then
        return false
    end
    if index == shown.highlight then
        return false
    end
    shown.highlight = index
    return true
end

function Session:move(delta)
    local shown = self.shown
    if not shown or #shown.items < 2 then
        return false
    end
    return self:select((shown.highlight - 1 + delta) % #shown.items + 1)
end

-- Hides the strip for the word being typed; the text is not touched.
function Session:dismiss()
    if not self.shown then
        return false
    end
    self.dismissed = { first = self.word.first, line = self.word.line }
    self.shown = nil
    return true
end

-- The edit for the highlighted item (see `completion.apply`), or nil when
-- hidden. The strip stays hidden for that word afterwards.
function Session:accept()
    local shown = self.shown
    if not shown then
        return nil
    end
    local ok, edit = pcall(completion.apply, self.text, self.word, shown.items[shown.highlight])
    self.dismissed = { first = self.word.first, line = self.word.line }
    self.shown = nil
    return ok and edit or nil
end

return M
