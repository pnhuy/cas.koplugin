-- Resumable plot job: samples each visible function, maps to screen space and
-- clips to the canvas. Work is sliced with a coroutine so the caller can keep
-- the UI responsive by calling step(budget) from UIManager ticks.

local clip = require("calcplot.clip")
local sampler = require("calcplot.sampler")
local viewport = require("calcplot.viewport")

local M = {}

local MAX_EVALS = 4000
local CHECK_EVERY = 32 -- evaluations between clock checks
local LIMIT = 1e12 -- keeps off-screen coordinates finite

local Job = {}
Job.__index = Job

local function limit(v)
    return v > LIMIT and LIMIT or (v < -LIMIT and -LIMIT or v)
end

local function to_screen_polyline(vp, w, h, line)
    local out = {}
    for i, p in ipairs(line) do
        local px, py = viewport.to_screen(vp, w, h, p[1], p[2])
        out[i] = { limit(px), limit(py) }
    end
    return out
end

local function clip_polyline(line, w, h, out)
    local cur
    local function flush()
        if cur then
            out[#out + 1] = cur
            cur = nil
        end
    end
    for i = 2, #line do
        local a, b = line[i - 1], line[i]
        local x1, y1, x2, y2 = clip.segment(a[1], a[2], b[1], b[2], 0, 0, w, h)
        if x1 then
            local last = cur and cur[#cur]
            if last and last[1] == x1 and last[2] == y1 then
                cur[#cur + 1] = { x2, y2 }
            else
                flush()
                cur = { { x1, y1 }, { x2, y2 } }
            end
        else
            flush()
        end
    end
    flush()
end

function Job:_run()
    local w, h = self.w, self.h
    local vp = self.vp
    local active = {}
    for _, f in ipairs(self.functions) do
        if f.visible then
            active[#active + 1] = f
        end
    end
    local tick = function()
        self.count = self.count + 1
        if self.count % CHECK_EVERY == 0 and os.clock() >= self.deadline then
            coroutine.yield()
        end
    end
    local reserved = 0
    if vp.auto_y then
        local all = {}
        for _, f in ipairs(active) do
            local ys = sampler.values(f.fn, vp.xmin, vp.xmax, w, tick)
            for _, y in ipairs(ys) do
                all[#all + 1] = y
            end
        end
        reserved = w + 1
        vp = viewport.auto_y(vp, all)
    end
    self.used = vp
    for _, f in ipairs(active) do
        local result = sampler.sample(f.fn, vp.xmin, vp.xmax, {
            samples = w,
            ymin = vp.ymin,
            ymax = vp.ymax,
            max_evals = MAX_EVALS - reserved,
            on_eval = tick,
        })
        local polylines = {}
        for _, line in ipairs(result.polylines) do
            clip_polyline(to_screen_polyline(vp, w, h, line), w, h, polylines)
        end
        self.curves[#self.curves + 1] = { id = f.id, style = f.style, polylines = polylines }
    end
end

-- Does about `budget` seconds of work; true once finished (or cancelled).
function Job:step(budget)
    if self.finished then
        return true
    end
    self.deadline = os.clock() + (budget or 0)
    local ok, err = coroutine.resume(self.co)
    if not ok then
        self.err = err
        self.curves = {}
        self.finished = true
    elseif coroutine.status(self.co) == "dead" then
        self.finished = true
    end
    return self.finished
end

function Job:result()
    return self.curves
end

-- The viewport actually plotted (with auto Y applied once known).
function Job:viewport()
    return self.used or self.vp
end

function Job:cancel()
    self.finished = true
    self.curves = {}
    self.co = nil
end

-- functions: { { id =, fn =, visible =, style = }, ... }
function M.new(functions, vp, w, h)
    assert(type(vp) == "table", "viewport required")
    assert(type(w) == "number" and w > 0 and type(h) == "number" and h > 0, "canvas size must be positive")
    local job = setmetatable({
        functions = functions,
        vp = vp,
        w = w,
        h = h,
        curves = {},
        count = 0,
        deadline = 0,
        finished = false,
    }, Job)
    job.co = coroutine.create(function()
        job:_run()
    end)
    return job
end

return M
