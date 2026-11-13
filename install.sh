#!/usr/bin/env bash
# One-shot setup: craftzdog-based Neovim (with my NvChad keymaps) + tmux
# code<->agent workflow. Works on WSL2 (Ubuntu/Debian), Arch, Fedora.
# Safe to re-run: existing configs are backed up with a timestamp.
#
#   cd ~/dotfiles-setup && ./install.sh
#
# Flags:  --no-packages   skip installing system packages / binaries
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
SKIP_PKGS=0
[[ "${1:-}" == "--no-packages" ]] && SKIP_PKGS=1

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
ver_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; } # ver_ge have need

BIN="$HOME/.local/bin"
OPT="$HOME/.local/opt"
mkdir -p "$BIN" "$OPT"
export PATH="$BIN:$PATH"

ARCH="$(uname -m)" # x86_64 | aarch64

nvim_version() { nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1; }

# Neovim from the official release tarball (distro packages are too old)
install_neovim_tarball() {
	local a="x86_64"
	[[ "$ARCH" == "aarch64" ]] && a="arm64"
	say "Installing latest Neovim release ($a) to $OPT/nvim"
	curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${a}.tar.gz" -o /tmp/nvim.tgz
	rm -rf "$OPT/nvim" && mkdir -p "$OPT/nvim"
	tar -xzf /tmp/nvim.tgz -C "$OPT/nvim" --strip-components=1
	ln -sf "$OPT/nvim/bin/nvim" "$BIN/nvim"
	rm -f /tmp/nvim.tgz
}

# lazygit from GitHub releases
install_lazygit() {
	local a="x86_64"
	[[ "$ARCH" == "aarch64" ]] && a="arm64"
	say "Installing lazygit"
	local url
	url="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest |
		jq -r --arg a "$a" '.assets[].browser_download_url | select(test("(?i)linux_" + $a + "\\.tar\\.gz$"))' | head -1)"
	[[ -n "$url" ]] || { warn "could not find lazygit release asset"; return; }
	curl -fsSL "$url" | tar -xz -C "$BIN" lazygit
}

# win32yank: lets Neovim (and tmux) inside WSL use the Windows clipboard
install_win32yank() {
	say "Installing win32yank (WSL clipboard bridge)"
	curl -fsSL https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip -o /tmp/win32yank.zip
	unzip -o -q /tmp/win32yank.zip win32yank.exe -d "$BIN"
	chmod +x "$BIN/win32yank.exe"
	rm -f /tmp/win32yank.zip
}

# Node LTS via nvm when node is missing or older than 20
install_node() {
	if have node && ver_ge "$(node -v | tr -d v)" "20.0.0"; then
		return
	fi
	say "Installing Node LTS via nvm"
	export NVM_DIR="$HOME/.nvm"
	[[ -s "$NVM_DIR/nvm.sh" ]] || curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
	# shellcheck disable=SC1091
	. "$NVM_DIR/nvm.sh"
	nvm install --lts
	nvm alias default 'lts/*'
}

# ---------------------------------------------------------------- 1. packages
if [[ $SKIP_PKGS -eq 0 ]]; then
	say "1/7 Installing system packages"
	if have apt-get; then
		sudo apt-get update
		sudo apt-get install -y tmux git ripgrep fd-find fzf jq unzip curl build-essential \
			openjdk-21-jdk golang-go xclip
		have fd || ln -sf "$(command -v fdfind)" "$BIN/fd"
		install_node
		nv="$(nvim_version || true)"
		if [[ -z "$nv" ]] || ! ver_ge "$nv" "0.12.0"; then install_neovim_tarball; fi
		have lazygit || install_lazygit
		if is_wsl; then have win32yank.exe || install_win32yank; fi
	elif have pacman; then
		sudo pacman -S --needed --noconfirm \
			neovim tmux git ripgrep fd fzf jq lazygit unzip curl gcc make \
			wl-clipboard xclip nodejs npm jdk-openjdk go
	elif have dnf; then
		sudo dnf install -y neovim tmux git ripgrep fd-find fzf jq unzip curl gcc make \
			wl-clipboard xclip nodejs npm java-21-openjdk golang
		have lazygit || install_lazygit
	else
		warn "Unknown package manager: install neovim>=0.12 tmux git ripgrep fd fzf jq lazygit gcc make nodejs npm yourself."
	fi
else
	say "1/7 Skipping system packages (--no-packages)"
fi

# ---------------------------------------------------------------- 2. checks
say "2/7 Checking versions"
have nvim || { warn "nvim not found"; exit 1; }
NV="$(nvim_version)"
ver_ge "$NV" "0.12.0" || { warn "Neovim $NV found — this config needs >= 0.12. Re-run without --no-packages."; exit 1; }
echo "nvim $NV ok"
have tmux && tmux -V || warn "tmux missing"
have node && echo "node $(node -v)" || warn "node missing: JS-based LSPs (vtsls, tailwind, eslint...) need it"
is_wsl && echo "WSL detected"

# ---------------------------------------------------------------- 3. backup
say "3/7 Backing up existing configs (suffix .bak-$TS)"
for d in ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim ~/.config/tmux; do
	if [[ -e "$d" ]]; then
		mv "$d" "$d.bak-$TS"
		echo "moved $d -> $d.bak-$TS"
	fi
done

# ---------------------------------------------------------------- 4. copy configs
say "4/7 Installing configs"
mkdir -p ~/.config
cp -r "$HERE/nvim" ~/.config/nvim
cp -r "$HERE/tmux" ~/.config/tmux
install -m 755 "$HERE/bin/dev" "$HERE/bin/dev-agent-toggle" "$BIN/"
for rc in ~/.bashrc ~/.zshrc; do
	[[ -f "$rc" ]] || continue
	grep -q 'HOME/.local/bin' "$rc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$rc"
done
mkdir -p ~/projects

# ---------------------------------------------------------------- 5. tmux plugins
say "5/7 Installing tmux plugins"
mkdir -p ~/.config/tmux/plugins
for repo in tmux-plugins/tpm tmux-plugins/tmux-pain-control craftzdog/tmux-claude-hatch; do
	name="${repo#*/}"
	[[ -d ~/.config/tmux/plugins/$name ]] || git clone -q --depth 1 "https://github.com/$repo" ~/.config/tmux/plugins/"$name"
	echo "ok $name"
done

# ---------------------------------------------------------------- 6. tree-sitter cli
say "6/7 Installing tree-sitter CLI (needed by nvim-treesitter)"
if have tree-sitter; then
	echo "already installed"
elif have npm; then
	npm install -g tree-sitter-cli || warn "npm global install failed"
else
	warn "npm missing — install tree-sitter-cli manually"
fi

# ---------------------------------------------------------------- 7. nvim bootstrap
say "7/7 Bootstrapping Neovim: plugins, treesitter parsers, Mason LSPs (~5-10 min)"
timeout 900 nvim --headless -c 'lua vim.defer_fn(function() vim.cmd("qa!") end, 480000)' >/dev/null 2>&1 || true
echo "Mason packages:"
ls ~/.local/share/nvim/mason/packages 2>/dev/null | sed 's/^/  /' || warn "Mason not finished — open nvim and wait"

if ! have claude; then
	warn "Claude Code not found. Install it inside WSL:  curl -fsSL https://claude.ai/install.sh | bash"
fi

say "Done!  Open a NEW terminal (so PATH/nvm load), then:"
cat <<'EOF'
  1. nvim            -> wait for anything still installing (:Mason to watch)
  2. :Copilot auth   (inside nvim, if you use Copilot)
  3. dev ~/projects/<something>
  Optional — Claude bell alerts, inside Claude Code:
       /plugin marketplace add craftzdog/tmux-claude-hatch
       /plugin install tmux-claude-hatch@tmux-claude-hatch
  Keep projects inside WSL (~/projects), not /mnt/c — much faster.
EOF
