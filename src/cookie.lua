local M = {}

M.jar = {}

function M.reset()
    M.jar = {}
end

function M.parse_set_cookie(set_cookie_header)
    if not set_cookie_header then
        return {}
    end
    local cookies = {}
    for raw in set_cookie_header:gmatch("[^,]+=[^,]*;?[^,]*") do
        local cookie_str = raw:match("^%s*(.-)%s*$")
        local name, value = cookie_str:match("^([^=;]+)=([^;]*)")
        if name and value ~= nil then
            cookies[name] = value
            M.jar[name] = value
        end
    end
    return cookies
end

function M.get(name)
    return M.jar[name]
end

function M.set(name, value)
    M.jar[name] = value
end

function M.build_cookie_header()
    local parts = {}
    for name, value in pairs(M.jar) do
        parts[#parts + 1] = name .. "=" .. value
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, "; ")
end

function M.has(name)
    return M.jar[name] ~= nil
end

function M.list()
    local entries = {}
    for k, v in pairs(M.jar) do
        entries[#entries + 1] = { name = k, value = v }
    end
    return entries
end

return M
