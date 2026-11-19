local form = require("lib.form")
local torrents = require("lib.torrents")

local M = {}

function M.handler()
    return function(req, res, ctx)
        local fields = form.fields(req)
        local allowed = ctx.user.allow_delete_files

        if allowed == nil then
            allowed = ctx.config.allow_delete_files == true
        end

        local delete_files = form.is_true(fields.deleteFiles)
        local keep_files = delete_files and not allowed

        local session_torrents = ctx.session:torrents()

        for _, t in ipairs(torrents.find(ctx, fields.hashes)) do
            if keep_files then
                print("Keeping files of", t.ts.name, "since allow_delete_files is off")
            end

            session_torrents:remove(t.th, { delete_files = delete_files and not keep_files })
        end

        res:write_status("200 OK")
        res:finish()
    end
end

return M
