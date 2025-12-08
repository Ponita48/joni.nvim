local M = {}

M.defaults = {

}

function M.setup()
    M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

    -- user command
    vim.api.nvim_create_user_command("JoniInsert",
        function()
            require("joni.generator").generate_here(M.options)
        end,
        {}
    )
end

return M
