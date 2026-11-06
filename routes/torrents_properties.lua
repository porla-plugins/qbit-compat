local json = require("porla_codec").json

local qbit = require("lib.qbit")
local query = require("lib.query")
local torrents = require("lib.torrents")

local M = {}

function M.handler()
    return function(req, res, ctx)
        local q = query.parse_query(req.query)
        local t = torrents.find(ctx, q.hash)[1]

        if not t then
            res:write_status("404 Not Found")
            return res:finish("Torrent hash was not found")
        end

        res:write_status("200 OK")
        res:write_header("Content-Type", "application/json")
        res:finish(json.encode(qbit.properties(t.ts)))
    end
end

return M
