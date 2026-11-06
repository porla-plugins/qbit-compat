local categories = require("lib.categories")
local paths = require("lib.paths")

local M = {}

function M.handler()
    return function(req, res, ctx)
        local category = req.form and req.form.fields and req.form.fields.category

        if not categories.valid_name(category) then
            res:write_status("409 Conflict")
            return res:finish()
        end

        local existing = categories.get()

        if not existing[category] then
            local entry = {}
            local save_path = req.form.fields.savePath

            if save_path ~= nil and save_path ~= "" then
                local resolved = paths.resolve(ctx.config.save_path, save_path)

                if not resolved then
                    res:write_status("409 Conflict")
                    return res:finish()
                end

                entry.save_path = paths.relative(ctx.config.save_path, resolved)
            end

            existing[category] = entry

            categories.set(existing)
        end

        res:write_status("200 OK")
        res:finish()
    end
end

return M
