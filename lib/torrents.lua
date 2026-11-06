local M = {}

---@class QbitTorrent
---@field th LtTorrentHandle
---@field ts LtTorrentStatus

---@param ctx QbitContext
---@param hashes? string|string[] # `|`-separated v1 or v2 hashes
---@return QbitTorrent[]
function M.find(ctx, hashes)
    local found = {}

    if type(hashes) ~= "string" then
        return found
    end

    local wanted = {}

    for hash in hashes:gmatch("[^|]+") do
        wanted[hash:lower()] = true
    end

    -- A scan, since PoTorrentsHandle:get only finds a hybrid torrent by both of its hashes and the
    -- *arrs send just the v1 one.
    for th, ts in ctx.session:torrents():list() do
        if wanted[ts.info_hash.v1] or wanted[ts.info_hash.v2] then
            found[#found + 1] = { th = th, ts = ts }
        end
    end

    return found
end

return M
