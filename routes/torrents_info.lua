local json = require("porla_codec").json

local qbit = require("lib.qbit")
local query = require("lib.query")

local M = {}

---@param value? string|string[]
---@return table<string, boolean>?
local function parse_hashes(value)
    if type(value) ~= "string" then
        return nil
    end

    local hashes = {}

    for hash in value:gmatch("[^|]+") do
        hashes[hash:lower()] = true
    end

    return hashes
end

function M.handler()
    return function(req, res, ctx)
        local q = query.parse_query(req.query)
        local hashes = parse_hashes(q.hashes)

        local items = json.array {}

        for th, ts in ctx.session:torrents():list() do
            local data = th:userdata()

            if data
                and (q.category == nil or (data.category or "") == q.category)
                and (hashes == nil or hashes[ts.info_hash.v1] or hashes[ts.info_hash.v2])
            then
                table.insert(items, qbit.encode(data, ts))
            end
        end

        res:write_status("200 OK")
        res:write_header("Content-Type", "application/json")
        res:finish(json.encode(items))
    end
end

return M
