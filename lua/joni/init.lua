local M = {}

function M.setup()
    -- user command
    vim.api.nvim_create_user_command("JoniInsert",
        function()
            require("joni.generator").generate_here()
        end,
        {}
    )
end

return M
