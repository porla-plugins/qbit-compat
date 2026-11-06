local kv = require("porla_kv")

local KEY = "plugins.qbit-compat.categories"

local M = {}

---@alias QbitCategories table<string, { save_path?: string }>

---@param name? string
---@return boolean
function M.valid_name(name)
    return name ~= nil
        and name ~= ""
        and #name <= 128
        and not name:find("[/\\]")
        and not name:find("..", 1, true)
end

---@return QbitCategories
function M.get()
    return kv.get(KEY) or {}
end

---@param categories QbitCategories
function M.set(categories)
    kv.set(KEY, categories)
end

return M
