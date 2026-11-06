local http_server = require("porla_http_server")
local presets = require("porla_presets")
local timers = require("porla_timers")

local auth = require("lib.auth")
local limits = require("lib.limits")

local app_preferences = require("routes.app_preferences")
local app_version = require("routes.app_version")
local app_webapiversion = require("routes.app_webapiversion")
local auth_login = require("routes.auth_login")
local torrents_add = require("routes.torrents_add")
local torrents_addtags = require("routes.torrents_addtags")
local torrents_categories = require("routes.torrents_categories")
local torrents_createcategory = require("routes.torrents_createcategory")
local torrents_delete = require("routes.torrents_delete")
local torrents_files = require("routes.torrents_files")
local torrents_info = require("routes.torrents_info")
local torrents_properties = require("routes.torrents_properties")
local torrents_setcategory = require("routes.torrents_setcategory")
local torrents_setforcestart = require("routes.torrents_setforcestart")
local torrents_setsharelimits = require("routes.torrents_setsharelimits")
local torrents_topprio = require("routes.torrents_topprio")

local function route(prefix, path)
    return string.format("%s/%s", prefix, path)
end

local function check_preset(name)
    local preset = type(name) == "string" and presets.get(name)

    if not preset then
        error(string.format("qbit-compat uses preset '%s', which doesn't exist", tostring(name)))
    end

    if preset.save_path or preset.session_id then
        print("Preset", name, "sets a save path or session, which qbit-compat overrides for its torrents")
    end
end

return {
    init = function(config)
        if not config
            or not config.users
            or next(config.users) == nil
        then
            error("qbit-compat requires at least one configured user")
        end

        for username, user in pairs(config.users) do
            if type(user.password_hash) ~= "string" then
                error(string.format("qbit-compat user '%s' needs a password_hash", username))
            end

            local session, session_name = auth.session_for(config, user)

            if not session then
                error(string.format("qbit-compat user '%s' has no loaded session '%s'", username, session_name))
            end
        end

        if type(config.save_path) ~= "string" or config.save_path:sub(1, 1) ~= "/" then
            error("qbit-compat needs an absolute save_path")
        end

        for _, key in ipairs({ "max_ratio", "max_seeding_time", "max_inactive_seeding_time" }) do
            if config[key] ~= nil and (type(config[key]) ~= "number" or config[key] < 0) then
                error(string.format("qbit-compat needs %s to be a number of 0 or more", key))
            end
        end

        if config.preset ~= nil then
            check_preset(config.preset)
        end

        if config.category_presets ~= nil and type(config.category_presets) ~= "table" then
            error("qbit-compat needs category_presets to be a table")
        end

        for _, name in pairs(config.category_presets or {}) do
            check_preset(name)
        end

        local prefix = config.prefix or "/api/qbit-compat"

        http_server.post(
            route(prefix, "api/v2/auth/login"),
            auth_login.handler(config.users))

        http_server.post(
            route(prefix, "api/v2/torrents/add"),
            auth.authed_route(config, torrents_add.handler()))

        http_server.post(
            route(prefix, "api/v2/torrents/addTags"),
            auth.authed_route(config, torrents_addtags.handler()))

        http_server.get(
            route(prefix, "api/v2/torrents/categories"),
            auth.authed_route(config, torrents_categories.handler()))

        http_server.post(
            route(prefix, "api/v2/torrents/createCategory"),
            auth.authed_route(config, torrents_createcategory.handler()))

        http_server.post(
            route(prefix, "api/v2/torrents/delete"),
            auth.authed_route(config, torrents_delete.handler()))

        http_server.get(
            route(prefix, "api/v2/torrents/files"),
            auth.authed_route(config, torrents_files.handler()))

        http_server.get(
            route(prefix, "api/v2/torrents/info"),
            auth.authed_route(config, torrents_info.handler()))

        http_server.get(
            route(prefix, "api/v2/torrents/properties"),
            auth.authed_route(config, torrents_properties.handler()))

        http_server.post(
            route(prefix, "api/v2/torrents/setCategory"),
            auth.authed_route(config, torrents_setcategory.handler()))

        http_server.post(
            route(prefix, "api/v2/torrents/setForceStart"),
            auth.authed_route(config, torrents_setforcestart.handler()))

        http_server.post(
            route(prefix, "api/v2/torrents/setShareLimits"),
            auth.authed_route(config, torrents_setsharelimits.handler()))

        http_server.post(
            route(prefix, "api/v2/torrents/topPrio"),
            auth.authed_route(config, torrents_topprio.handler()))

        http_server.get(
            route(prefix, "api/v2/app/preferences"),
            auth.authed_route(config, app_preferences.handler()))

        http_server.get(
            route(prefix, "api/v2/app/version"),
            auth.authed_route(config, app_version.handler()))

        http_server.get(
            route(prefix, "api/v2/app/webapiVersion"),
            auth.authed_route(config, app_webapiversion.handler()))

        timers.interval(60 * 1000, function()
            limits.enforce(config)
        end)

        http_server.get(route(prefix, "*"), function(req, res)
            print("Unhandled request:", req.method, req.path)
            res:write_status("501 Not Implemented")
            res:finish()
        end)

        http_server.post(route(prefix, "*"), function(req, res)
            print("Unhandled request:", req.method, req.path)
            res:write_status("501 Not Implemented")
            res:finish()
        end)
    end
}
