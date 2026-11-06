local categories = require("lib.categories")
local form = require("lib.form")
local torrents = require("lib.torrents")

local M = {}

function M.handler()
    return function(req, res, ctx)
        local fields = form.fields(req)
        local category = fields.category or ""

        if category ~= "" and not categories.get()[category] then
            res:write_status("409 Conflict")
            return res:finish()
        end

        for _, t in ipairs(torrents.find(ctx, fields.hashes)) do
            local data = t.th:userdata()

            if data then
                data:update({ category = category ~= "" and category or porla.null })
            end
        end

        res:write_status("200 OK")
        res:finish()
    end
end

return M
