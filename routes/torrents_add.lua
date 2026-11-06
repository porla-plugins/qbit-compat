local categories = require("lib.categories")
local form = require("lib.form")
local limits = require("lib.limits")
local paths = require("lib.paths")

local M = {}

---@param request_form PoHttpServerRequestForm
---@return LtAddTorrentParams[]
local function parse_params(request_form)
    local params = {}

    for _, file in ipairs(request_form.files) do
        local atp, err = LtAddTorrentParams.from_buffer(file:data())

        if atp then
            params[#params + 1] = atp
        else
            print("Invalid torrent file:", file.name, err)
        end
    end

    for url in (request_form.fields.urls or ""):gmatch("[^\r\n]+") do
        local atp, err = LtAddTorrentParams.from_magnet(url)

        if atp then
            params[#params + 1] = atp
        else
            print("Invalid url:", url, err)
        end
    end

    return params
end

function M.handler()
    return function(req, res, ctx)
        if not req.form or (#req.form.files == 0 and not req.form.fields.urls) then
            res:write_status("400 Bad Request")
            return res:finish("Fails.")
        end

        local fields = req.form.fields
        local category = fields.category ~= "" and fields.category or nil

        if category and not categories.valid_name(category) then
            print("Invalid category:", category)
            return res:finish("Fails.")
        end

        local known_categories = categories.get()
        local requested_path = fields.savepath

        if (requested_path == nil or requested_path == "") and category and known_categories[category] then
            requested_path = known_categories[category].save_path
        end

        local save_path = paths.resolve(ctx.config.save_path, requested_path)

        if not save_path then
            print("Refusing save path outside save_path:", requested_path)
            return res:finish("Fails.")
        end

        local paused = form.is_true(fields.paused) or form.is_true(fields.stopped)
        local sequential = form.is_true(fields.sequentialDownload)
        local tags = form.parse_tags(fields.tags)
        local metadata = limits.metadata(limits.from_fields(fields))

        local config = ctx.config
        local preset = category and config.category_presets and config.category_presets[category] or config.preset
        local add_opts = preset and { preset = preset } or nil

        local torrents = ctx.session:torrents()
        local added = 0

        for _, atp in ipairs(parse_params(req.form)) do
            atp.save_path = save_path
            atp.userdata = { category = category, tags = tags, metadata = metadata }

            -- Without unsetting auto_managed, libtorrent's queue resumes the torrent.
            if paused then
                atp.flags:set("paused")
                atp.flags:unset("auto_managed")
            end

            if sequential then
                atp.flags:set("sequential_download")
            end

            local _, err = torrents:add(atp, add_opts)

            if err then
                print("Failed to add torrent:", err)
            else
                added = added + 1
            end
        end

        if added > 0 and category and not known_categories[category] then
            known_categories[category] = {}
            categories.set(known_categories)
        end

        res:write_status("200 OK")
        res:finish(added > 0 and "Ok." or "Fails.")
    end
end

return M
