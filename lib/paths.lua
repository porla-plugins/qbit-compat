local M = {}

local function trim_trailing_slashes(path)
    return (path:gsub("(.)/+$", "%1"))
end

local function prefix_of(root)
    return root == "/" and "/" or root .. "/"
end

---@param root string
---@param path? string # relative paths resolve against `root`
---@return string? # nil when the path is outside `root`
function M.resolve(root, path)
    root = trim_trailing_slashes(root)

    if path == nil or path == "" then
        return root
    end

    if path:sub(1, 1) ~= "/" then
        path = root .. "/" .. path
    end

    path = trim_trailing_slashes(path)

    for segment in path:gmatch("[^/]+") do
        if segment == "." or segment == ".." then
            return nil
        end
    end

    local prefix = prefix_of(root)

    if path ~= root and path:sub(1, #prefix) ~= prefix then
        return nil
    end

    return path
end

---@param root string
---@param path string # a path from `resolve`
---@return string? # nil for `root` itself
function M.relative(root, path)
    root = trim_trailing_slashes(root)

    if path == root then
        return nil
    end

    return path:sub(#prefix_of(root) + 1)
end

return M
