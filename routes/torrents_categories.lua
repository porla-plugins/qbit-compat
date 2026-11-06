local json = require("porla_codec").json

local categories = require("lib.categories")
local paths = require("lib.paths")

local M = {}

function M.handler()
    return function(_, res, ctx)
        local out = {}

        for name, entry in pairs(categories.get()) do
            out[name] = {
                name     = name,
                savePath = entry.save_path and paths.resolve(ctx.config.save_path, entry.save_path) or ""
            }
        end

        res:write_status("200 OK")
        res:write_header("Content-Type", "application/json")
        res:finish(json.encode(out))
    end
end

return M
