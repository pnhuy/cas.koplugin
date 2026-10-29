-- Plotting engine facade (see specs/001-calculator-cas-graphing/contracts/plot-api.md).
-- A top-level file because KOReader's plugin package.path has no ?/init.lua.

return {
    new = require("calcplot.plot").new,
    viewport = require("calcplot.viewport"),
    ticks = require("calcplot.ticks"),
}
