local https = require "ssl.https"
local ltn12 = require "ltn12"
local io = require "io"
local inspect = require "inspect"
local logger = require "src.logger"
local cookie = require "src.cookie"

local M = {}

M.base_headers = {}

function M.load_headers(path)
    path = path or "headers.txt"
    local file = io.open(path, "r")
    if not file then
        logger.error("cannot open headers file: " .. path)
        return
    end
    M.base_headers = {}
    for line in file:lines() do
        local key, value = line:match("^(%S+): (.+)$")
        if key and value then
            M.base_headers[key] = value
        end
    end
    file:close()
    local count = 0
    for _ in pairs(M.base_headers) do count = count + 1 end
    logger.info("loaded " .. count .. " base headers from " .. path)
end

function M.build_headers(extra)
    extra = extra or {}
    local headers = {}
    for k, v in pairs(M.base_headers) do
        headers[k] = v
    end
    for k, v in pairs(extra) do
        headers[k] = v
    end
    local cookie_str = cookie.build_cookie_header()
    if cookie_str then
        headers["Cookie"] = cookie_str
    end
    return headers
end

function M.get(url, opts)
    opts = opts or {}
    local resp_body = {}
    local sink = ltn12.sink.table(resp_body)

    local req = {
        url = url,
        headers = M.build_headers(opts.headers),
        sink = sink,
        redirect = opts.redirect
    }

    logger.separator()
    logger.request("GET", url, req.headers)

    local _, status, resp_headers = https.request(req)

    local body = table.concat(resp_body)
    logger.response(status, resp_headers)
    logger.preview(body)

    if resp_headers then
        if resp_headers["set-cookie"] then
            cookie.parse_set_cookie(resp_headers["set-cookie"])
            logger.info("cookies after parse: " .. inspect.inspect(cookie.list()))
        end
    end

    return body, status, resp_headers
end

function M.get_to_file(url, filepath, opts)
    opts = opts or {}
    local file = io.open(filepath, "wb")
    if not file then
        logger.error("cannot open file for writing: " .. filepath)
        return nil, nil, nil
    end

    local sink = ltn12.sink.file(file)

    local req = {
        url = url,
        headers = M.build_headers(opts.headers),
        sink = sink,
        redirect = opts.redirect
    }

    logger.separator()
    logger.request("GET", url, req.headers)

    local _, status, resp_headers = https.request(req)
    file:close()

    logger.response(status, resp_headers, filepath)

    if resp_headers and resp_headers["set-cookie"] then
        cookie.parse_set_cookie(resp_headers["set-cookie"])
        logger.info("cookies after parse: " .. inspect.inspect(cookie.list()))
    end

    return status, resp_headers
end

function M.get_with_cookies(url)
    local cookie_str = cookie.build_cookie_header()
    local extra = {}
    if cookie_str then
        extra["Cookie"] = cookie_str
    end
    return M.get(url, { headers = extra })
end

return M
