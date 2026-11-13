return {
	filetypes = { "go", "gomod", "gowork", "gotmpl" },
	settings = {
		gopls = {
			gofumpt = true,
			completeUnimported = true,
			usePlaceholders = true,
			staticcheck = true,
			analyses = { unusedparams = true, unusedwrite = true, nilness = true, shadow = false },
			codelenses = { gc_details = false, generate = true, tidy = true, upgrade_dependency = true },
		},
	},
}
