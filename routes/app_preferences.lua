local codec = require("porla_codec")
local json = codec.json

local qbit = require("lib.qbit")

local M = {}

function M.handler()
    ---@param res PoHttpServerResponse
    return function(_, res, ctx)
        local config = ctx.config

        res:write_status("200 OK")
        res:write_header("Content-Type", "application/json")
        res:finish(json.encode({
            ["save_path"] = config.save_path,
            ["max_ratio_enabled"] = config.max_ratio ~= nil,
            ["max_ratio"] = config.max_ratio or -1,
            ["max_ratio_act"] = 0,
            ["max_seeding_time_enabled"] = config.max_seeding_time ~= nil,
            ["max_seeding_time"] = config.max_seeding_time or -1,
            ["max_inactive_seeding_time_enabled"] = config.max_inactive_seeding_time ~= nil,
            ["max_inactive_seeding_time"] = config.max_inactive_seeding_time or -1,
            ["queueing_enabled"] = qbit.queueing_enabled(ctx.session),
            ["dht"] = ctx.session:get_settings().enable_dht,
            ["listen_port"] = 6881,
            ["random_port"] = false
        }))
    end
end

return M
