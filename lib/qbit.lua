local json = require("porla_codec").json

local limits = require("lib.limits")

---@param ts LtTorrentStatus
local function eta(ts)
    local eta = 8640000
    if ts.download_payload_rate > 0 then
        eta = math.floor((ts.total_wanted - ts.total_wanted_done) / ts.download_payload_rate)
        if eta < 0 or eta > 8640000 then eta = 8640000 end
    end
    return eta
end

---@param ts LtTorrentStatus
local function content_path(ts)
    local ti = ts.torrent_file

    if not ti then
        return ts.save_path
    end

    local save_path = ts.save_path:gsub("/+$", "")
    local filenames = LtFilenames(ti:layout(), ts.renamed_files)
    local first     = filenames:file_path(0, save_path)

    if ti:num_files() == 1 then
        return first
    end

    local rest = first:sub(#save_path + 2)
    local root = rest:match("^([^/]+)/")

    if not root then
        return save_path
    end

    return save_path .. "/" .. root
end

---@param ts LtTorrentStatus
local function state(ts)
    if ts.moving_storage then
        return "moving"
    end

    if ts.errc then
        return "error"
    end

    -- TODO: missing files?

    local is_auto_managed = ts.flags:has("auto_managed")
    local is_paused = ts.flags:has("paused")

    local user_forced = (not is_auto_managed and not is_paused)
    local suffix = ts.is_finished and "UP" or "DL"

    if is_paused then
        return (is_auto_managed and "queued" or "paused") .. suffix
    end

    if ts.state == "checking_files" or ts.state == "checking_resume_data" then
        if ts.progress < 1.0 then
            return "checkingDL"
        else
            return "checkingUP"
        end
    end

    if ts.state == "downloading_metadata" then
        if user_forced then
            return "forcedMetaDL"
        else
            return "metaDL"
        end
    end

    if ts.state == "downloading" then
        if user_forced then
            return "forcedDL"
        elseif ts.download_payload_rate > 0 then
            return "downloading"
        else
            return "stalledDL"
        end
    end

    if ts.state == "finished" or ts.state == "seeding" then
        if user_forced then
            return "forcedUP"
        elseif ts.upload_payload_rate > 0 then
            return "uploading"
        else
            return "stalledUP"
        end
    end

    return "unknown"
end

local M = {}

---@param data PoTorrentData
---@param ts LtTorrentStatus
function M.encode(data, ts)
    local tags = data:tags()
    table.sort(tags)

    local share_limits = limits.get(data)

    return {
        ["hash"] = ts.info_hash:hex(),
        ["name"] = ts.name,
        ["size"] = ts.total_wanted,
        ["amount_left"] = ts.total_wanted - ts.total_wanted_done,
        ["progress"] = ts.progress,
        ["eta"] = eta(ts),
        ["state"] = state(ts),
        ["category"] = data.category or "",
        ["tags"] = table.concat(tags, ", "),
        ["save_path"] = ts.save_path,
        ["content_path"] = content_path(ts),
        ["dlspeed"] = ts.download_payload_rate,
        ["upspeed"] = ts.upload_payload_rate,
        ["ratio"] = ts.ratio,
        ["ratio_limit"] = share_limits.ratio_limit or -2,
        ["seeding_time"] = ts.seeding_duration,
        ["seeding_time_limit"] = share_limits.seeding_time_limit or -2,
        ["inactive_seeding_time_limit"] = share_limits.inactive_seeding_time_limit or -2,
        ["last_activity"] = limits.last_activity(ts),
        ["added_on"] = ts.added_time
    }
end

---@param ts LtTorrentStatus
function M.properties(ts)
    local ti = ts.torrent_file

    return {
        ["hash"] = ts.info_hash:hex(),
        ["name"] = ts.name,
        ["save_path"] = ts.save_path,
        ["addition_date"] = ts.added_time,
        ["completion_date"] = ts.completed_time or -1,
        ["time_elapsed"] = ts.active_duration,
        ["seeding_time"] = ts.seeding_duration,
        ["total_size"] = ts.total_wanted,
        ["total_downloaded"] = ts.all_time_download,
        ["total_uploaded"] = ts.all_time_upload,
        ["dl_speed"] = ts.download_payload_rate,
        ["up_speed"] = ts.upload_payload_rate,
        ["share_ratio"] = ts.ratio,
        ["eta"] = eta(ts),
        ["nb_connections"] = ts.num_connections,
        ["seeds"] = ts.num_seeds,
        ["peers"] = ts.num_peers - ts.num_seeds,
        ["pieces_num"] = ti and ti:num_pieces() or -1,
        ["pieces_have"] = ts.num_pieces
    }
end

---@param th LtTorrentHandle
---@param ts LtTorrentStatus
function M.files(th, ts)
    local files = json.array {}
    local ti = ts.torrent_file

    if not ti then
        return files
    end

    local layout = ti:layout()
    local names = LtFilenames(layout, ts.renamed_files)
    local progress = th:file_progress()

    for i = 0, names:num_files() - 1 do
        local name = names:file_path(i)
        local size = layout:file_size(i)

        -- BEP 47 pad files, which qBittorrent hides and leaves out of the numbering.
        if not (name:find("^%.pad/") or name:find("/%.pad/")) then
            files[#files + 1] = {
                ["index"] = #files,
                ["name"] = name,
                ["size"] = size,
                ["progress"] = size > 0 and progress[i + 1] / size or 1
            }
        end
    end

    return files
end

---libtorrent treats a negative limit as unlimited, which turns its queue off.
---@param session PoSessionHandle
---@return boolean
function M.queueing_enabled(session)
    local settings = session:get_settings()
    return settings.active_downloads >= 0 or settings.active_limit >= 0
end

return M
