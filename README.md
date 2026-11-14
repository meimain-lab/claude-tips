# claude-tips

Claude Code 速查表：不用记功能名，查一下“该说什么、该输入什么”。

每条提示有中文说明和一句可以直接用的英文原文（美式口语或斜杠命令）。同一份内容有两个前端：

| 前端 | 在哪里 | 点一行的效果 |
|---|---|---|
| 侧边面板（`pane/`） | Claude 桌面应用里，聊天区旁边 | 把英文原文填进输入框，发不发由你决定 |
| 菜单栏应用（`menubar/`） | macOS 菜单栏，不在 Claude 窗口里也能查 | 把英文原文复制到剪贴板 |

两个前端都是纯本地界面：只读本机文件，不向 Claude 的会话注入任何内容，也不给会话增加工具、skill 或 agent。

## 安装

需要 macOS 13 或更新版本、Python 3，以及 Swift 工具链（装了 Xcode 或 Command Line Tools 都行：`xcode-select --install`）。

### 1. 取得代码并安装内容文件

```bash
git clone https://github.com/meimain-lab/claude-tips.git
```

```bash
cd claude-tips
```

```bash
scripts/install-content.sh
```

`install-content.sh` 会先校验 `content/tips.json`，再把它复制到 `~/.claude/claude-tips/tips.json`。它从不改动你自己的 `tips.local.json`。

### 2. 侧边面板

面板是一个 Claude Code 的 mod（插件名 `tips-pane`）。三种装法任选一种：

- **Claude 桌面应用**：点输入框旁边的 **+**，选 **Plugins** → **Add marketplace**，填 `meimain-lab/claude-tips`（也可以填第 1 步克隆下来的文件夹路径），再 **Add plugin** 选 `tips-pane`。
- **终端里的 Claude Code 会话**：输入下面这行，提示添加 marketplace 时回答 `y`，再选安装范围。

  ```
  /plugin install tips-pane --marketplace meimain-lab/claude-tips
  ```

- **命令行**：

  ```bash
  claude plugin install tips-pane --marketplace meimain-lab/claude-tips
  ```

装好后，在新会话里输入 `/tips` 打开面板，再输入一次关闭。

### 3. 菜单栏应用

```bash
scripts/build-menubar-app.sh
```

```bash
cp -R "build/Claude Tips.app" ~/Applications/
```

```bash
open ~/Applications/"Claude Tips.app"
```

打包脚本用 `swift build -c release` 编译，生成 `build/Claude Tips.app`，并做 ad-hoc 签名。应用只在菜单栏显示图标，不出现在 Dock 里。

**开机自动启动**：打开“系统设置 → 通用 → 登录项与扩展”，在“登录时打开”下点 **+**，选 `~/Applications/Claude Tips.app`。应用里没有写自启代码，想关掉时在同一处删掉即可。

## 使用

### 侧边面板

- `/tips`：打开或关闭面板。`/tips 关键词` 打开面板并直接搜索。
- 面板从上到下是搜索框、「直接说」「斜杠命令」「我的」三组，以及有内容时出现的「未整理」。
- 点一行：英文原文填进输入框，行尾显示「已填入」。如果当前没有输入框可填，就改为复制到剪贴板，显示「已复制」。

### 菜单栏应用

| 操作 | 效果 |
|---|---|
| 点菜单栏图标或按 `⌥⌘K` | 打开浮层，光标在搜索框；再按一次关闭 |
| 直接打字 | 搜索，忽略分组，跨组显示结果 |
| `↑` `↓` | 移动选中行 |
| `↵` 或点击行 | 复制英文原文，显示「已复制」后浮层自动关闭 |
| `→` / `←`，或点行尾箭头 | 进入 / 退出详情 |
| `⌘1` `⌘2` `⌘3`（有「未整理」时还有 `⌘4`） | 切换分组 |
| `esc` | 有搜索词时先清空，否则关闭 |

如果 `⌥⌘K` 已被别的应用占用，就点菜单栏图标打开。

退出应用：右键点菜单栏图标，选「退出 Claude Tips」；或者在浮层打开时按 `⌘Q`。

搜索规则：不区分大小写，在中文说明、英文原文和关键词里找。排序是标题开头匹配优先，然后是标题包含、关键词命中、英文原文命中。

## 加自己的条目

把 [content/tips.local.example.json](content/tips.local.example.json) 复制到 `~/.claude/claude-tips/tips.local.json`，再改成自己的。这个文件只在你的电脑上，不会进仓库（`.gitignore` 也排除了它）。

- 条目写法和 `content/tips.json` 一样，`group` 用 `mine` 就会出现在「我的」。
- `id` 和公开条目相同时，你的条目会替换公开条目。
- 想隐藏某条公开条目，加一条 `{ "id": "那条的 id", "hidden": true }`。
- 校验你的文件：`scripts/validate-tips.py --local ~/.claude/claude-tips/tips.local.json`。

**「未整理」分组**：两个前端都会只读扫描 `~/.claude/skills/*/SKILL.md`。没被任何条目引用的 skill 会出现在「未整理」，标题是 skill 名，原文是 `/skill 名`。条目引用的 skill 已经从磁盘删掉时，这一行变灰，并标注「已不存在」。扫描结果只在内存里，不会写进任何文件。

两个前端每次打开都会重新读这些文件，改完就生效。

## 更新内容

改内置条目：

1. 编辑 `content/tips.json`。
2. 运行 `scripts/validate-tips.py` 校验。如果它提示 `pane/assets/tips.json` 过期了，运行 `scripts/sync-pane-fallback.sh`。
3. 运行 `scripts/install-content.sh`，装到运行位置。

`pane/assets/tips.json` 和 `.app` 里的 `tips.json` 都是后备副本，只在 `~/.claude/claude-tips/tips.json` 不存在或损坏时使用。它们由脚本生成，不要手工编辑。

Claude Code 升级后，内置 skill 可能有增减或改名。把 [docs/refresh-tips-prompt.md](docs/refresh-tips-prompt.md) 里的 prompt 贴给 Claude Code，它会列出需要新增、改名和移除的条目，等你确认后再改。

## 开发

```bash
claude plugin validate pane
```

```bash
claude plugin test pane
```

```bash
swift test --package-path menubar
```

- 侧边面板的代码在 `pane/hooks/`，状态类型在 `pane/types/index.d.ts`，测试在 `pane/tests/`。
- 菜单栏应用是一个 Swift package：`TipsCore`（模型、读取、合并、搜索、skill 扫描，不含界面）和 `ClaudeTipsMenuBar`（AppKit 外壳和 SwiftUI 界面）。测试用 Swift Testing，只装 Command Line Tools 也能跑。
- 应用图标的源图是 `menubar/Resources/app-icon-source.png`；`scripts/make-app-icon.sh` 把它套上 macOS 圆角网格并生成 `AppIcon.icns`，打包脚本每次都会重新生成，换图后重新打包即可。
- `menubar/.build/debug/ClaudeTipsMenuBar --snapshot <文件夹>` 会把浮层的几种状态在浅色和深色下各渲染成一张 PNG，不用打开菜单栏就能检查样式。

## 卸载

- 侧边面板：在 Claude 桌面应用的 Plugins 里移除 `tips-pane`，或运行 `claude plugin uninstall tips-pane`。
- 菜单栏应用：退出应用，删掉 `~/Applications/Claude Tips.app`，并从登录项里移除。
- 内容文件：删掉 `~/.claude/claude-tips/`。注意里面的 `tips.local.json` 是你自己写的。

## 许可

MIT，见 [LICENSE](LICENSE)。
