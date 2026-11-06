local form = require("lib.form")
local torrents = require("lib.torrents")

local M = {}

function M.handler()
    return function(req, res, ctx)
        local fields = form.fields(req)
        local force = form.is_true(fields.value)

        local auto_managed = LtTorrentFlags()
        auto_managed:set("auto_managed")

        for _, t in ipairs(torrents.find(ctx, fields.hashes)) do
            if force then
                t.th:unset_flags(auto_managed)
                t.th:resume()
            else
                t.th:set_flags(auto_managed)
            end
        end

        res:write_status("200 OK")
        res:finish()
    end
end

return M
