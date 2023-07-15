-- import null-ls plugin safely
local setup, null_ls = pcall(require, "null-ls")
if not setup then
	return
end

local null_helpers = require("null-ls.helpers")

-- for conciseness
local formatting = null_ls.builtins.formatting -- to setup formatters
local diagnostics = null_ls.builtins.diagnostics -- to setup linters

-- to setup format on save
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

local cfn_lint = {
	method = null_ls.methods.DIAGNOSTICS,
	filetypes = { "yaml" },
	generator = null_helpers.generator_factory({
		command = "cfn-lint",
		to_stdin = true,
		to_stderr = true,
		args = { "--format", "parseable", "-" },
		format = "line",
	}),
	check_exit_code = function(code)
		return code == 0 or code == 255
	end,
	on_output = function(line, params)
		local row, col, end_row, end_col, code, message = line:match(":(%d+):(%d+):(%d+):(%d+):(.*):(.*)")
		local severity = null_helpers.diagnostics.severities["error"]

		if message == nil then
			return nil
		end

		if vim.startswith(code, "E") then
			severity = null_helpers.diagnostics.severities["error"]
		elseif vim.startswith(code, "W") then
			severity = null_helpers.diagnostics.severities["warning"]
		else
			severity = null_helpers.diagnostics.severities["information"]
		end

		return {
			message = message,
			code = code,
			row = row,
			col = col,
			end_col = end_col,
			end_row = end_row,
			severity = severity,
			source = "cfn-lint",
		}
	end,
}
-- configure null_ls
null_ls.setup({
	-- setup formatters & linters
	sources = {
		--  to disable file types use
		--  "formatting.prettier.with({disabled_filetypes = {}})" (see null-ls docs)
		cfn_lint,
		formatting.prettier, -- js/ts formatter
		formatting.stylua, -- lua formatter
		formatting.goimports, -- go imports
		diagnostics.eslint_d.with({ -- js/ts linter
			-- only enable eslint if root has .eslintrc.js (not in youtube nvim video)
			condition = function(utils)
				return utils.root_has_file(".eslintrc.js") -- change file extension if you use something else
			end,
		}),
	},
	-- configure format on save
	on_attach = function(current_client, bufnr)
		if current_client.supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.format({
						filter = function(client)
							--  only use null-ls for formatting instead of lsp server
							return client.name == "null-ls"
						end,
						bufnr = bufnr,
					})
				end,
			})
		end
	end,
})
