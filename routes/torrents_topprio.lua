local form = require("lib.form")
local qbit = require("lib.qbit")
local torrents = require("lib.torrents")

local M = {}

function M.handler()
    return function(req, res, ctx)
        if not qbit.queueing_enabled(ctx.session) then
            res:write_status("409 Conflict")
            return res:finish("Torrent queueing must be enabled")
        end

        for _, t in ipairs(torrents.find(ctx, form.fields(req).hashes)) do
            t.th:queue_position_top()
        end

        res:write_status("200 OK")
        res:finish()
    end
end

return M
