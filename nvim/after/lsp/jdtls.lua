-- jdtls itself needs Java 21+. Your projects can still use an older JDK.
-- Pick the newest JDK >= 21 found on this machine (Arch/Debian/Fedora paths,
-- SDKMAN), falling back to $JAVA_HOME.
local function find_java_home()
	local candidates = {}
	for _, pattern in ipairs({
		"/usr/lib/jvm/*",
		vim.fn.expand("~/.sdkman/candidates/java/*"),
	}) do
		vim.list_extend(candidates, vim.fn.glob(pattern, false, true))
	end
	local best, best_ver = nil, 0
	for _, dir in ipairs(candidates) do
		local ver = tonumber(dir:match("java%-(%d+)") or dir:match("jdk%-?(%d+)") or dir:match("/(%d+)[%.%-]"))
		if ver and ver >= 21 and ver > best_ver and vim.fn.executable(dir .. "/bin/java") == 1 then
			best, best_ver = dir, ver
		end
	end
	return best or vim.env.JAVA_HOME
end

return {
	cmd_env = { JAVA_HOME = find_java_home() },
	settings = {
		java = {
			signatureHelp = { enabled = true },
			contentProvider = { preferred = "fernflower" },
			completion = {
				favoriteStaticMembers = {
					"org.hamcrest.MatcherAssert.assertThat",
					"org.hamcrest.Matchers.*",
					"org.junit.jupiter.api.Assertions.*",
				},
			},
			sources = { organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 } },
		},
	},
}
