local strip_keys = require("calcnb.strip_keys")

describe("calcnb.strip_keys", function()
    it("maps Press and Tab to accept, Back to dismiss, page keys to the highlight", function()
        assert.are.equal("accept", strip_keys.action({ Press = true }, true))
        assert.are.equal("accept", strip_keys.action({ Tab = true }, true))
        assert.are.equal("dismiss", strip_keys.action({ Back = true }, true))
        assert.are.equal("next", strip_keys.action({ RPgFwd = true }, true))
        assert.are.equal("next", strip_keys.action({ LPgFwd = true }, true))
        assert.are.equal("prev", strip_keys.action({ RPgBack = true }, true))
        assert.are.equal("prev", strip_keys.action({ LPgBack = true }, true))
    end)

    it("takes no key while the strip is hidden", function()
        for _, k in ipairs({ "Press", "Tab", "Back", "RPgFwd", "LPgBack" }) do
            assert.is_nil(strip_keys.action({ [k] = true }, false))
        end
    end)

    it("ignores other keys and malformed input", function()
        assert.is_nil(strip_keys.action({ Left = true }, true))
        assert.is_nil(strip_keys.action({}, true))
        assert.is_nil(strip_keys.action(nil, true))
        assert.is_nil(strip_keys.action("Press", true))
    end)
end)
