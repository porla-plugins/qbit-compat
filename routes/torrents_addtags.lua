local form = require("lib.form")
local torrents = require("lib.torrents")

local M = {}

function M.handler()
    return function(req, res, ctx)
        local fields = form.fields(req)
        local new_tags = form.parse_tags(fields.tags)

        if not new_tags then
            res:write_status("400 Bad Request")
            return res:finish()
        end

        for _, t in ipairs(torrents.find(ctx, fields.hashes)) do
            local data = t.th:userdata()

            if data then
                local tags = data:tags()

                for _, tag in ipairs(new_tags) do
                    if not data:has_tag(tag) then
                        tags[#tags + 1] = tag
                    end
                end

                data:update({ tags = tags })
            end
        end

        res:write_status("200 OK")
        res:finish()
    end
end

return M
