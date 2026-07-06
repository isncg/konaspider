local io = require "io"
local os = require "os"

local M = {}

M.log_path = "crawler.log"

local function log_file()
    local f = io.open(M.log_path, "a")
    if not f then
        error("cannot open log file: " .. M.log_path)
    end
    return f
end

local function timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

function M.write(...)
    local args = {...}
    local parts = {}
    for _, v in ipairs(args) do
        parts[#parts + 1] = tostring(v)
    end
    local msg = table.concat(parts, " ")
    local f = log_file()
    f:write("[" .. timestamp() .. "] " .. msg .. "\n")
    f:close()
end

function M.separator()
    local f = log_file()
    f:write(string.rep("-", 72) .. "\n")
    f:close()
end

function M.request(method, url, headers)
    local f = log_file()
    f:write("[" .. timestamp() .. "] >>> REQUEST: " .. method .. " " .. url .. "\n")
    if headers then
        for k, v in pairs(headers) do
            f:write("  " .. k .. ": " .. v .. "\n")
        end
    end
    f:close()
end

function M.response(status, headers, body_path)
    local f = log_file()
    f:write("[" .. timestamp() .. "] <<< RESPONSE: " .. status .. "\n")
    if headers then
        for k, v in pairs(headers) do
            f:write("  " .. k .. ": " .. v .. "\n")
        end
    end
    if body_path then
        f:write("  body saved to: " .. body_path .. "\n")
    end
    f:close()
end

function M.preview(body, max_bytes)
    max_bytes = max_bytes or 600
    local f = log_file()
    f:write(string.sub(tostring(body), 1, max_bytes) .. "\n")
    f:close()
end

function M.info(msg)
    M.write("INFO", msg)
end

function M.warn(msg)
    M.write("WARN", msg)
end

function M.error(msg)
    M.write("ERROR", msg)
end

return M
