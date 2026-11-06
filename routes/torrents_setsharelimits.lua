local form = require("lib.form")
local limits = require("lib.limits")
local torrents = require("lib.torrents")

local M = {}

function M.handler()
    return function(req, res, ctx)
        local fields = form.fields(req)
        local share_limits = limits.from_fields(fields)

        for _, t in ipairs(torrents.find(ctx, fields.hashes)) do
            local data = t.th:userdata()

            if data then
                limits.set(data, share_limits)
            end
        end

        res:write_status("200 OK")
        res:finish()
    end
end

return M
