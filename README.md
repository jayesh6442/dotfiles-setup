# dotfiles-setup — Neovim + tmux (code ↔ AI agent)

Neovim config from [craftzdog/dotfiles-public](https://github.com/craftzdog/dotfiles-public)
with **my old NvChad keymaps**, extra LSPs, and a tmux setup for hopping between
code and an AI agent (Claude / Codex / OpenCode / Gemini).

## Windows (WSL2) — full setup

tmux only runs on Linux, so on Windows everything lives inside **WSL2 (Ubuntu)**.

**A. Windows side (once)**
1. Admin PowerShell: `wsl --install -d Ubuntu` → reboot → create your Linux user.
2. Install a **Nerd Font on Windows** (e.g. JetBrainsMono Nerd Font: https://www.nerdfonts.com) →
   Windows Terminal → Settings → Ubuntu profile → Appearance → Font face.
3. Windows Terminal → Settings → Startup → Default profile = **Ubuntu**.
4. Windows Terminal → Settings → Actions: remove any binding on `Ctrl+T`, `Alt+H`, `Alt+V`, `Alt+I`,
   `Ctrl+Shift+Left/Right` so they reach tmux/nvim.

**B. Inside Ubuntu**
```sh
git clone <this repo> ~/dotfiles-setup      # or copy the folder in via \\wsl$\Ubuntu\home\<you>
cd ~/dotfiles-setup && ./install.sh
```
On Ubuntu/WSL `install.sh` installs: apt packages (tmux, git, ripgrep, fd, fzf, jq, build tools,
OpenJDK 21, Go), **Neovim latest** (official tarball → `~/.local/opt/nvim`), **lazygit**, **Node LTS**
(via nvm, if missing/old), **win32yank** (Windows clipboard bridge for nvim + tmux), then copies the
configs, clones tmux plugins, installs tree-sitter-cli and bootstraps all nvim plugins/LSPs.

**C. After install** — open a *new* terminal, then:
```sh
curl -fsSL https://claude.ai/install.sh | bash   # Claude Code inside WSL (if not installed)
nvim                                             # let anything left finish (:Mason)
dev ~/projects/<something>
```
In nvim: `:Copilot auth`.

**WSL notes**
- Keep projects in `~/projects` (Linux filesystem). `/mnt/c/...` is very slow for git/LSP/search.
  From Windows they're at `\\wsl$\Ubuntu\home\<you>\projects`.
- Clipboard: nvim auto-uses `win32yank.exe`; tmux copy-mode uses it too (falls back to `clip.exe`).
- `prefix o` opens the folder in Windows Explorer.
- `prefix f` project picker searches `~/projects` (+ other roots in `PROJECT_ROOTS` in `~/.local/bin/dev`).

## Other Linux (Arch / Fedora)

```sh
cd ~/dotfiles-setup && ./install.sh     # or --no-packages if you install packages yourself
```

---

## What's in here

```
nvim/                      -> ~/.config/nvim
  init.lua                    entry point
  nvim-pack-lock.json         pinned plugin versions (vim.pack lockfile)
  lua/craftzdog/config/       options, keymaps (MY keys), autocmds, commands
  lua/craftzdog/plugins/      plugin list (init.lua) + setup per area
  after/lsp/*.lua             per-language-server settings
  craftzdog-keymaps.lua.orig  craftzdog's original keymaps (disabled, for reference)
tmux/                      -> ~/.config/tmux   (plugins/ is cloned by install.sh)
  tmux.conf  bindings.conf  theme.conf  statusline.conf  utility.conf
bin/                       -> ~/.local/bin
  dev                         open a project: nvim | agent layout
  dev-agent-toggle            prefix+a: jump between nvim and the agent pane
install.sh                 does everything below automatically
```

---

## Everything that was done (manual steps, in order)

### 0. Requirements
| Tool | Why |
|---|---|
| **Neovim ≥ 0.12** | config uses built-in `vim.pack` and the new ui2 cmdline |
| tmux ≥ 3.2 (3.8 tested) | popups, plugins |
| git, gcc, make, unzip, curl | plugins + treesitter parser builds |
| ripgrep, fd, fzf, jq | pickers, project picker, claude-hatch |
| node + npm | tree-sitter-cli and JS-based LSPs |
| lazygit | `prefix g` popup |
| wl-clipboard (Wayland) or xclip (X11) | tmux copy → system clipboard |
| JDK ≥ 21 (optional) | to run the Java LSP (auto-detected in `/usr/lib/jvm`, SDKMAN) |
| Go (optional) | gopls |

Arch: `sudo pacman -S --needed neovim tmux git ripgrep fd fzf jq lazygit unzip curl gcc make wl-clipboard xclip nodejs npm`

### 1. Back up the old config
```sh
for d in ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim ~/.config/tmux; do
  [ -e "$d" ] && mv "$d" "$d.bak"
done
```

### 2. Neovim
```sh
cp -r nvim ~/.config/nvim
npm i -g tree-sitter-cli                    # nvim-treesitter (main branch) needs it
nvim                                        # first start installs plugins, parsers, LSPs — wait
```

Changes made on top of craftzdog's config:

1. **Keymaps** — `lua/craftzdog/config/keymaps.lua` contains my NvChad v2.5 default + custom keys.
   craftzdog's plugin keymaps (`plugins/keymaps.lua`) are emptied. NvChad-only targets remapped:
   | Keys | Old | Now |
   |---|---|---|
   | `<leader>ff fw fb fo fz fh fa ma cm gt th` | Telescope | Snacks picker |
   | `<C-n>` / `<leader>e` | nvim-tree (right) | Snacks explorer (right) |
   | `<A-v> <A-h> <A-i>`, `<leader>h/v` | nvchad.term | Snacks terminal |
   | `<Tab> <S-Tab> <leader>x <leader>b` | tabufline | `:bnext` / `:bprev` / bufdelete / enew |
   | `<leader>ch`, `<leader>wK/wk` | cheatsheet / which-key | Snacks keymaps picker |
   | `<C-h/j/k/l>` | window move | window move **+ continues into tmux panes** |
   Unchanged: `;`→`:`, `jk`, `gr`, `<leader>rn`, `<leader>f`, `<leader>fm`, `gd gD <leader>D <leader>ra <leader>wa/wr/wl`,
   `<C-s>`, `<C-c>`, `<leader>/`, `<leader>n`, `<leader>ds`, insert-mode `<C-b/e/h/j/k/l>`, `<C-x>` in terminal.
   New: `<leader>aa` jump to agent pane, `<leader>as` send `@file` (visual: `@file#L10-20`) to agent.
2. **Completion** — blink.cmp keymap set to nvim-cmp style (`plugins/editor.lua`):
   `<Tab>/<S-Tab>` select, `<CR>` accept, `<C-Space>` show, `<C-e>` hide, `<C-d>/<C-f>` scroll docs, `<C-p>/<C-n>`.
3. **Mouse** re-enabled (`config/options.lua`: `vim.opt.mouse = "a"`).
4. **LSPs** (`plugins/lsp.lua`) — added to Mason + `vim.lsp.enable`: `css-lsp`, `html-lsp`(html),
   `json-lsp`(jsonls), `gopls`, `jdtls`. Settings ported from the old config into `after/lsp/`:
   `html.lua` (templ/htmldjango), `gopls.lua` (gofumpt, staticcheck…), `rust_analyzer.lua` (clippy, allFeatures),
   `jdtls.lua` (Java settings + auto-picks a JDK ≥ 21 to run the server).
   Full list: lua_ls, vtsls, oxlint, eslint, tailwindcss, cssls, html, jsonls, gopls, rust_analyzer, jdtls (+ copilot).

### 3. tmux
```sh
cp -r tmux ~/.config/tmux
mkdir -p ~/.config/tmux/plugins && cd ~/.config/tmux/plugins
git clone --depth 1 https://github.com/tmux-plugins/tpm
git clone --depth 1 https://github.com/tmux-plugins/tmux-pain-control
git clone --depth 1 https://github.com/craftzdog/tmux-claude-hatch
```
Changes vs craftzdog's tmux config:
- Linux: removed macOS bits; clipboard via `wl-copy`/`xclip`; `xdg-open` for `prefix o`.
- `tmux-256color` + RGB for kitty, undercurl; mouse on; windows/panes start at 1.
- **Removed `window-style fg=colour10` / `window-active-style fg=colour12`** — with my kitty
  palette those made all pane text dark navy (unreadable).
- Seamless `C-h/j/k/l` between nvim and tmux panes (`bindings.conf` + nvim `keymaps.lua`).
- `prefix C-l` = clear screen (re-bound after tpm because pain-control overrides it).
- New: `prefix a` (agent toggle), `prefix f` (project picker → `dev`), `prefix S` (session switcher).

### 4. Scripts
```sh
install -m 755 bin/dev bin/dev-agent-toggle ~/.local/bin/
```
- `dev [dir]` / `dev --pick` → session named after the folder; window 1 `code` = nvim (60%) | agent (40%),
  window 2 `shell`. Agent = `$DEV_AGENT` (default `claude`). Project roots for `--pick` are listed at
  the top of the script — edit `PROJECT_ROOTS` for the new machine.

### 5. One-time manual bits
- `:Copilot auth` in nvim.
- Claude bell alerts (in Claude Code): `/plugin marketplace add craftzdog/tmux-claude-hatch` then
  `/plugin install tmux-claude-hatch@tmux-claude-hatch`.

---

## Key cheat sheet

**tmux (prefix = `Ctrl-t`)**

| Key | Action |
|---|---|
| `C-h/j/k/l` (no prefix) | move between panes / nvim splits |
| `prefix a` | nvim ↔ agent pane |
| `prefix y` / `prefix d` / `prefix u` | Claude popup / hide it / list all agents |
| `prefix f` / `prefix S` | open project / switch session |
| `prefix z` | zoom pane |
| `prefix c`, `1-9`, `n`/`p`, `,` | new / go to / next-prev / rename window |
| `prefix \|` / `-` | split vertical / horizontal |
| `prefix H/J/K/L` | resize pane |
| `prefix x` / `e` / `&` | kill pane / other panes / window |
| `prefix g` | lazygit |
| `prefix [` → `v` … `y` | copy mode → copy to clipboard |
| `prefix C-l` | clear shell |
| `prefix r` / `?` | reload config / list all keys |
| `prefix d` | detach (`dev <dir>` to come back) |
| `Ctrl-t Ctrl-t` | send literal Ctrl-t |

**Neovim (`<leader>` = Space)** — find: `ff fw fb fo fz fa fh`; tree: `<C-n>` `<leader>e`;
buffers: `<Tab> <S-Tab> <leader>x`; LSP: `gd gD gr K <leader>rn <leader>ra <leader>D <leader>ds`;
format: `<leader>fm` / `<leader>f`; comment: `<leader>/`; terminals: `<A-i> <A-h> <A-v>`;
agent: `<leader>aa` `<leader>as`; all keys: `<leader>ch`.

## Updating
- Plugins: `:lua vim.pack.update()` then `:w` (lockfile `nvim-pack-lock.json` updates — commit it).
- tmux plugins: `prefix U`.
- After changing configs on this machine, copy them back here:
  `rsync -a --exclude .git ~/.config/nvim/ nvim/ && rsync -a --exclude plugins ~/.config/tmux/ tmux/ && cp ~/.local/bin/dev* bin/`
