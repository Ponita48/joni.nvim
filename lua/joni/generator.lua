local M = {}

local function call_command(json, template, endpoint_name, method_name)
    local plugin_dir = debug.getinfo(1).source
    plugin_dir = string.sub(plugin_dir, 1)
    plugin_dir = string.match(plugin_dir, "@(.+)/%a+.%a+")

    local cmd = {
        "python3",
        plugin_dir .. '/' .. 'joni.py',
        vim.fn.fnameescape(json),
        endpoint_name,
        method_name,
        "--template=" .. vim.fn.fnameescape(template),
    }

    return vim.system(cmd, { text = true}):wait()
end

local function insert_result(result)
    if result.code ~= 0 then
        vim.notify("Python script failed: " .. (result.stderr or "Unknown error"), vim.log.levels.ERROR)
        return
    end

    local output = result.stdout or ""
    output = output:gsub("\n$", "")

    if output == "" then
        vim.notify("Python script returned no output", vim.log.levels.WARN)
        return
    end

    -- Get current cursor position
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))

    -- Split result into lines
    local lines = vim.split(output, "\n")

    -- Insert the text at cursor position
    if #lines == 1 then
        -- Single line: insert at current cursor position
        local current_line = vim.api.nvim_get_current_line()
        local new_line = current_line:sub(1, col) .. lines[1] .. current_line:sub(col + 1)
        vim.api.nvim_set_current_line(new_line)
        -- Move cursor to end of inserted text
        vim.api.nvim_win_set_cursor(0, { row, col + #lines[1] })
    else
        -- Multiple lines: insert at cursor and create new lines as needed
        local current_line = vim.api.nvim_get_current_line()
        local before_cursor = current_line:sub(1, col)
        local after_cursor = current_line:sub(col + 1)

        -- Prepare lines to insert
        local insert_lines = {}
        insert_lines[1] = before_cursor .. lines[1]
        for i = 2, #lines - 1 do
            insert_lines[i] = lines[i]
        end
        insert_lines[#lines] = lines[#lines] .. after_cursor

        -- Replace current line and add additional lines
        vim.api.nvim_buf_set_lines(0, row - 1, row, false, insert_lines)
        -- Move cursor to end of inserted text
        vim.api.nvim_win_set_cursor(0, { row + #lines - 1, #lines[#lines] })
    end

    vim.notify("Python script output inserted successfully!")
end

local function input_method_name(json, template, endpoint_name)
    vim.ui.input({ prompt = "Input your method name: " }, function(input)
        if input == nil then return end

        local result = call_command(json, template, endpoint_name, input)
        insert_result(result)
    end)
end

local function input_endpoint_name(json, template)
    vim.ui.input({ prompt = "Input your endpoint name: " }, function(input)
        if input == nil then return end

        input_method_name(json, template, input)
    end)
end

local function select_template(json)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local config_values = require("telescope.config").values
    local previewers = require("telescope.previewers")

    local template_dir = debug.getinfo(1).source
    template_dir = string.sub(template_dir, 1)
    template_dir = string.match(template_dir, "@(.+)/%a+.%a+")
    template_dir = template_dir .. '/templates'

    pickers.new({}, {
        prompt_title = "Select Template to Use",
        finder = finders.new_oneshot_job(
            { "sh", "-c", string.format("find %s -type f -name '*.j2'", template_dir) }, {}),
        sorter = config_values.generic_sorter({}),
        previewer = previewers.vim_buffer_cat.new({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()[1]
                if not selection then return end
                actions.close(prompt_bufnr)

                local file = vim.fn.fnamemodify(selection, ":t")
                input_endpoint_name(json, file)
            end)

            return true
        end,
    }):find()
end

local function select_json_file()
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local config_values = require("telescope.config").values
    local previewers = require("telescope.previewers")

    pickers.new({}, {
        prompt_title = "Select JSON to Convert",
        finder = finders.new_oneshot_job({ "find", ".", "-type", "f", "-name", "*.json" }, {}),
        sorter = config_values.generic_sorter({}),
        previewer = previewers.vim_buffer_cat.new({}),
        attach_mappings = function(prompt_bufnr, _)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)

                local selection = action_state.get_selected_entry()[1]
                if not selection then return end

                select_template(selection)
            end)

            return true
        end,
    }):find()
end

function M.generate_here()
    select_json_file()
end

return M
