local notebook = require("calcnb.notebook")

local function new_with(sources)
  local nb = notebook.new("T")
  nb.cells = {}
  for _, src in ipairs(sources) do
    local c = assert(nb:add(#nb.cells + 1))
    assert(nb:set_source(c.id, src))
  end
  return nb
end

describe("calcnb.notebook structure", function()
  it("starts with one empty code cell", function()
    local nb = notebook.new()
    assert.are.equal("Notebook", nb.title)
    assert.are.equal(1, #nb.cells)
    assert.are.equal("code", nb.cells[1].type)
    assert.are.equal("", nb.cells[1].source)
    assert.are.equal("idle", nb.cells[1].status)
  end)

  it("adds above and below", function()
    local nb = new_with({ "a", "b" })
    local ids = { nb.cells[1].id, nb.cells[2].id }
    local above = nb:add_above(ids[2])
    local below = nb:add_below(ids[2])
    assert.are.equal(4, #nb.cells)
    assert.are.equal(above.id, nb.cells[2].id)
    assert.are.equal(below.id, nb.cells[4].id)
  end)

  it("never reuses ids", function()
    local nb = notebook.new()
    local first = nb.cells[1].id
    local c = nb:add(2)
    nb:delete(c.id)
    local d = nb:add(2)
    assert.is_true(d.id > c.id)
    assert.are_not.equal(first, d.id)
  end)

  it("duplicates source and viewport without output", function()
    local nb = new_with({ "plot(x)" })
    local c = nb.cells[1]
    c.output = { kind = "graph" }
    c.exec_number = 1
    c.viewport = { x_min = -1, x_max = 1 }
    local d = nb:duplicate(c.id)
    assert.are.equal(2, #nb.cells)
    assert.are.equal(d.id, nb.cells[2].id)
    assert.are.equal("plot(x)", d.source)
    assert.is_nil(d.output)
    assert.is_nil(d.exec_number)
    assert.are.same(c.viewport, d.viewport)
    assert.are_not.equal(c.viewport, d.viewport)
    assert.are.equal("idle", d.status)
  end)

  it("deleting the last cell leaves one empty cell", function()
    local nb = new_with({ "a" })
    nb:delete(nb.cells[1].id)
    assert.are.equal(1, #nb.cells)
    assert.are.equal("", nb.cells[1].source)
  end)

  it("moves cells and stays in bounds", function()
    local nb = new_with({ "a", "b", "c" })
    local a = nb.cells[1].id
    assert.is_true(nb:move(a, 1))
    assert.are.equal(2, nb:index_of(a))
    assert.is_false(nb:move(a, 5))
    assert.is_false(nb:move(nb.cells[1].id, -1))
    assert.are.equal(2, nb:index_of(a))
  end)

  it("caps the notebook at 200 cells", function()
    local nb = notebook.new()
    for _ = 2, 200 do
      assert(nb:add(#nb.cells + 1))
    end
    local c, err = nb:add(#nb.cells + 1)
    assert.is_nil(c)
    assert.are.equal("limit", err.kind)
    local d, derr = nb:duplicate(nb.cells[1].id)
    assert.is_nil(d)
    assert.are.equal("limit", derr.kind)
  end)

  it("trims the title and falls back to the default", function()
    local nb = notebook.new()
    nb:set_title("  Algebra  ")
    assert.are.equal("Algebra", nb.title)
    nb:set_title("   ")
    assert.are.equal("Notebook", nb.title)
    nb:set_title(string.rep("x", 100))
    assert.are.equal(60, #nb.title)
  end)
end)

describe("calcnb.notebook source", function()
  it("normalizes line endings and tabs", function()
    local nb = notebook.new()
    local c = nb.cells[1]
    assert(nb:set_source(c.id, "a = 1\r\nb\t= 2\rc"))
    assert.are.equal("a = 1\nb  = 2\nc", c.source)
  end)

  it("rejects invalid UTF-8 and overlong text without changing the cell", function()
    local nb = notebook.new()
    local c = nb.cells[1]
    assert(nb:set_source(c.id, "ok"))
    local ok, err = nb:set_source(c.id, "bad \255\254")
    assert.is_nil(ok)
    assert.are.equal("encoding", err.kind)
    ok, err = nb:set_source(c.id, string.rep("x", 5001))
    assert.is_nil(ok)
    assert.are.equal("limit", err.kind)
    assert.are.equal("ok", c.source)
  end)

  it("accepts multi-byte text", function()
    local nb = notebook.new()
    assert(nb:set_source(nb.cells[1].id, "π = 3"))
    assert.are.equal("π = 3", nb.cells[1].source)
  end)

  it("marks an existing output out of date when the source changes", function()
    local nb = new_with({ "1+1" })
    local c = nb.cells[1]
    nb:run_cell(c.id)
    assert.is_false(c.out_of_date)
    nb:set_source(c.id, "1+2")
    assert.is_true(c.out_of_date)
    assert.is_truthy(c.output)
  end)

  it("does not flag a cell that never ran or whose text is unchanged", function()
    local nb = new_with({ "1+1" })
    local c = nb.cells[1]
    nb:set_source(c.id, "1+2")
    assert.is_false(c.out_of_date)
    nb:run_cell(c.id)
    nb:set_source(c.id, "1+2")
    assert.is_false(c.out_of_date)
  end)
end)

describe("calcnb.notebook running", function()
  it("shares the environment between cells", function()
    local nb = new_with({ "a = 2", "a^2 + 1" })
    nb:run_cell(nb.cells[1].id)
    nb:run_cell(nb.cells[2].id)
    assert.are.equal("5", nb.cells[2].output.canonical)
    assert.are.equal("completed", nb.cells[2].status)
    assert.are.equal(2, nb.cells[2].exec_number)
  end)

  it("sets the error status and keeps the notebook usable", function()
    local nb = new_with({ "sin(", "1+1" })
    nb:run_cell(nb.cells[1].id)
    assert.are.equal("error", nb.cells[1].status)
    assert.are.equal("error", nb.cells[1].output.kind)
    nb:run_cell(nb.cells[2].id)
    assert.are.equal("completed", nb.cells[2].status)
  end)

  it("ignores text cells", function()
    local nb = notebook.new()
    local t = nb:add(2, "text")
    nb:set_source(t.id, "notes")
    assert.is_nil(nb:run_cell(t.id))
    assert.are.equal("idle", t.status)
  end)

  it("marks later executed cells stale when a name changes", function()
    local nb = new_with({ "a = 1", "a + 1", "5" })
    for _, c in ipairs(nb.cells) do
      nb:run_cell(c.id)
    end
    nb:set_source(nb.cells[1].id, "a = 10")
    nb:run_cell(nb.cells[1].id)
    assert.are.equal("stale", nb.cells[2].status)
    assert.are.equal("stale", nb.cells[3].status)
    assert.are.equal("completed", nb.cells[1].status)
  end)

  it("does not mark cells stale when nothing changed", function()
    local nb = new_with({ "a = 1", "a + 1" })
    for _, c in ipairs(nb.cells) do
      nb:run_cell(c.id)
    end
    nb:run_cell(nb.cells[1].id)
    assert.are.equal("completed", nb.cells[2].status)
  end)

  it("a stale cell becomes completed again when run", function()
    local nb = new_with({ "a = 1", "a + 1" })
    for _, c in ipairs(nb.cells) do
      nb:run_cell(c.id)
    end
    nb:set_source(nb.cells[1].id, "a = 5")
    nb:run_cell(nb.cells[1].id)
    nb:run_cell(nb.cells[2].id)
    assert.are.equal("completed", nb.cells[2].status)
    assert.are.equal("6", nb.cells[2].output.canonical)
  end)

  it("marks executed cells stale on reorder and delete", function()
    local nb = new_with({ "a = 1", "a + 1", "2" })
    for _, c in ipairs(nb.cells) do
      nb:run_cell(c.id)
    end
    nb:move(nb.cells[3].id, -1)
    for _, c in ipairs(nb.cells) do
      assert.are.equal("stale", c.status)
    end
    nb:run_cell(nb.cells[1].id)
    nb:delete(nb.cells[3].id)
    assert.are.equal("stale", nb.cells[1].status)
  end)

  it("clear_output resets one cell, clear_all_outputs all of them", function()
    local nb = new_with({ "1", "2" })
    nb:run_cell(nb.cells[1].id)
    nb:run_cell(nb.cells[2].id)
    nb:clear_output(nb.cells[1].id)
    assert.is_nil(nb.cells[1].output)
    assert.are.equal("idle", nb.cells[1].status)
    assert.is_truthy(nb.cells[2].output)
    nb:clear_all_outputs()
    assert.is_nil(nb.cells[2].output)
    assert.are.equal("idle", nb.cells[2].status)
  end)

  it("run_all resets the environment and returns the code cell ids in order", function()
    local nb = new_with({ "a = 2", "a * 3" })
    nb:run_cell(nb.cells[1].id)
    nb:run_cell(nb.cells[2].id)
    nb:set_source(nb.cells[1].id, "a = 4")
    local ids = nb:begin_run_all()
    assert.are.same({ nb.cells[1].id, nb.cells[2].id }, ids)
    for _, id in ipairs(ids) do
      nb:run_cell(id)
    end
    assert.are.equal("12", nb.cells[2].output.canonical)
    assert.are.equal("completed", nb.cells[2].status)
  end)

  it("a cell that uses a variable not yet defined reports it", function()
    local nb = new_with({ "a + 1" })
    nb:run_cell(nb.cells[1].id)
    assert.are.equal("completed", nb.cells[1].status)
    assert.are.equal("a+1", nb.cells[1].output.canonical)
  end)
end)

describe("calcnb.notebook graph viewport", function()
  it("drops a saved viewport when the source changes but not when it is unchanged", function()
    local nb = notebook.new("T")
    local id = nb.cells[1].id
    nb:set_source(id, "plot(sin(x))")
    nb.cells[1].viewport = { xmin = -1, xmax = 1, ymin = -1, ymax = 1 }
    nb:set_source(id, "plot(sin(x))")
    assert.is_table(nb.cells[1].viewport)
    nb:set_source(id, "plot(cos(x))")
    assert.is_nil(nb.cells[1].viewport)
  end)
end)
