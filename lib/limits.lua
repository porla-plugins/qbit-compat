local auth = require("lib.auth")
local categories = require("lib.categories")

local KEY = "qbit-compat"

local M = {}

---Like qBittorrent: -2 uses the configured limit, -1 is no limit. Times are minutes.
---@class QbitShareLimits
---@field ratio_limit? number
---@field seeding_time_limit? integer
---@field inactive_seeding_time_limit? integer

---@param fields table<string, string>
---@return QbitShareLimits
function M.from_fields(fields)
    return {
        ratio_limit = tonumber(fields.ratioLimit),
        seeding_time_limit = tonumber(fields.seedingTimeLimit),
        inactive_seeding_time_limit = tonumber(fields.inactiveSeedingTimeLimit)
    }
end

---@param limits QbitShareLimits
---@return table<string, any>? # torrent metadata holding `limits`, nil when it sets none
function M.metadata(limits)
    if next(limits) == nil then
        return nil
    end

    return { [KEY] = limits }
end

---@param data PoTorrentData
---@return QbitShareLimits
function M.get(data)
    return data:metadata(KEY) or {}
end

---Limits left out of `limits` keep their stored value.
---@param data PoTorrentData
---@param limits QbitShareLimits
function M.set(data, limits)
    local merged = M.get(data)

    for key, value in pairs(limits) do
        merged[key] = value
    end

    data:update({ metadata = M.metadata(merged) })
end

---@param ts LtTorrentStatus
---@return integer
function M.last_activity(ts)
    return math.max(ts.last_download or 0, ts.last_upload or 0, ts.added_time or 0)
end

---@param own? number
---@param global? number
---@return number?
local function effective(own, global)
    if own == nil or own == -2 then
        return global
    end

    if own < 0 then
        return nil
    end

    return own
end

---@param config table
---@param data PoTorrentData
---@param ts LtTorrentStatus
---@param now integer
local function reached(config, data, ts, now)
    local own = M.get(data)
    local ratio = effective(own.ratio_limit, config.max_ratio)
    local seeding_time = effective(own.seeding_time_limit, config.max_seeding_time)
    local inactive_time = effective(own.inactive_seeding_time_limit, config.max_inactive_seeding_time)

    -- Sonarr removes a torrent only when it agrees the limit is reached, using this same 0.001 slack.
    return (ratio ~= nil and ratio - ts.ratio <= 0.001)
        or (seeding_time ~= nil and ts.seeding_duration >= seeding_time * 60)
        or (inactive_time ~= nil and now - M.last_activity(ts) >= inactive_time * 60)
end

---@param config table
---@param session PoSessionHandle
---@param known_categories QbitCategories
---@param now integer
local function enforce_session(config, session, known_categories, now)
    local auto_managed = LtTorrentFlags()
    auto_managed:set("auto_managed")

    for th, ts in session:torrents():list() do
        local data = th:userdata()

        if data
            and data.category
            and known_categories[data.category]
            and ts.is_finished
            and not (ts.flags:has("paused") and not ts.flags:has("auto_managed"))
            and reached(config, data, ts, now)
        then
            print("Pausing", ts.name, "at its seed limit")

            th:unset_flags(auto_managed)
            th:pause()
        end
    end
end

---@param config table
function M.enforce(config)
    local now = os.time()
    local known_categories = categories.get()
    local done = {}

    for _, user in pairs(config.users) do
        local session = auth.session_for(config, user)

        if session and not done[session.id] then
            done[session.id] = true
            enforce_session(config, session, known_categories, now)
        end
    end
end

return M
