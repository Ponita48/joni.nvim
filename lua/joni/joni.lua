local M = {
    attrs = {}
}

local function capitalize_first(input)
    return string.upper(string.sub(input, 1, 1)) .. string.sub(input, 2)
end

local function to_camel_case(input)
    local finalString = string.gsub(input, "_(%w)", capitalize_first)

    return string.lower(string.sub(finalString, 1, 1)) .. string.sub(finalString, 2)
end

local function extract_attrs(entity, prefix)
    if type(entity) == "table" then
        for k, v in pairs(entity) do
            if (type(k) == "number" and k > 1) then goto continue end

            if (prefix ~= nil) then
                if (type(k) == "number") then
                    k = prefix .. '.first'
                else
                    k = prefix .. '.' .. k
                end
            end

            extract_attrs(v, k)

            ::continue::
        end
    else
        table.insert(M.attrs, { ["key"] = to_camel_case(prefix), ["value"] = entity })
    end
end

local function read_json(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "Couldn't open file: " .. path
    end

    local content = file:read("*all")
    file:close()

    local ok, decoded = pcall(vim.json.decode, content)
    if not ok then
        return nil, "Failed to parse JSON: " .. decoded
    end

    return decoded
end

local function read_template(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "Couldn't open file: " .. path
    end

    local template_content = file:read("*all")
    file:close()

    return template_content
end

function M.render(attrs)
    local template = attrs.template

    local json = read_json(attrs.jsonName)
    local template_content = read_template(template)

    local etlua = require('joni.etlua')

    if (json ~= nil and template_content ~= nil) then
        M.attrs = {}
        extract_attrs(json)

        local result = etlua.compile(template_content)

        return result({
            response = {
                name = attrs.endpoint,
                attrs = M.attrs,
                jsonName = attrs.jsonName,
                statusCode = attrs.statusCode
            },
            method = {
                name = attrs.methodName
            }
        })
    else
        vim.print('json or template_content is nil')
    end
end

return M
