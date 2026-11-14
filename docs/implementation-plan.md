# claude-tips 实施计划

状态：设计已获批准（2026-11-14），本文件是实现依据。实现者读完本文件即可开工，不需要其他背景。

## 1. 要做的东西

一个 Claude Code 速查表（cheat sheet），帮不熟悉功能名的人快速查到“该说什么、该输入什么”。两个前端共用一份内容：

| 前端 | 位置 | 用在什么时候 | 点一行的效果 |
|---|---|---|---|
| 侧边面板（pane） | `pane/`，Claude Code 的 mod | 人就在 Claude 桌面应用里 | 把英文原文填进聊天输入框 |
| 菜单栏应用（menu bar app） | `menubar/`，原生 macOS 应用 | 不在 Claude 窗口里也能查 | 把英文原文复制到剪贴板 |

每条提示有两部分：**中文说明**（界面上显示）和**英文原文**（被填入或复制的内容）。英文是自然的美式口语或斜杠命令。

视觉目标见 `docs/design/menubar-target-light.png` 和 `docs/design/side-pane-target-dark.png`。这两张是生图模型画的效果图，用来对齐观感，不是像素级标准；图里与本文件不一致的地方以本文件为准。

## 2. 硬性约束

1. **纯本地界面。** 两个前端都不得向模型上下文注入任何内容，不得给会话增加工具、skill、agent 或 system prompt 片段。面板把文字填进输入框是用户点击后的动作，发不发由用户决定，这是允许的。
2. **公开仓库里不得出现个人或雇主信息**：姓名、邮箱、公司名、产品名、本机用户名、`/Users/<name>` 这类路径。清单文件里的 `author` / `owner` 一律写 `claude-tips contributors`。每次提交前检查一遍 diff。
3. **用户自己的 skill 不进仓库。** 它们只存在于本机的 `~/.claude/claude-tips/tips.local.json`，仓库里只有 `content/tips.local.example.json` 这个示例。
4. **命名**：文件、目录、标识符、JSON 键用清晰的英文；文件和目录用 kebab-case，Swift 类型用 PascalCase，TypeScript 变量用 camelCase。代码注释和 commit message 用英文；界面文案和文档用简体中文。
5. **Git**：只在本仓库已设置 `user.email` 时提交；没设置就不提交，并在汇报里说明。不要自行设置或猜测身份。不要 push，不要创建远程仓库，这两步由用户来做。
6. **不改用户的全局设置**（`~/.claude/settings.json` 等）。需要改时停下来问用户。

## 3. 仓库结构

```
claude-tips/
  README.md
  LICENSE                         MIT
  .gitignore
  .claude-plugin/marketplace.json 让别人能从仓库根安装 pane 这个 mod
  content/
    tips.json                     公开内容：Claude Code 内置条目（唯一来源）
    tips.local.example.json       本机覆盖文件的示例
  docs/
    implementation-plan.md        本文件
    refresh-tips-prompt.md        维护用 prompt（里程碑 M7 写）
    design/                       两张效果图
  scripts/
    validate-tips.py              内容校验（M1）
    install-content.sh            把 content/tips.json 装到运行位置（M1）
    build-menubar-app.sh          打包 .app（M3）
  pane/                           mod：.claude-plugin/plugin.json、hooks/、types/、tests
  menubar/                        Swift package
```

## 4. 内容文件

### 4.1 结构

`content/tips.json` 已写好 13 条内置条目，结构如下（字段含义看文件即可）：

| 字段 | 说明 |
|---|---|
| `id` | kebab-case，全局唯一 |
| `group` | `say`（直接说）、`slash`（斜杠命令）、`mine`（我的） |
| `title` | 中文说明，一行，界面主文字 |
| `copy` | 英文原文，被填入或复制；只允许 ASCII |
| `detail` | 中文详情，两三句，详情层显示 |
| `keywords` | 中英文同义词，供搜索 |
| `icon` | SF Symbols 名称；面板可以映射到自己的图标或不显示 |
| `source` | `{ kind, name }`，说明这条对应哪个 skill、工具或命令 |

### 4.2 运行时读取

- 运行目录：`~/.claude/claude-tips/`。
  - `tips.json`：由 `scripts/install-content.sh` 从仓库复制过来，更新时覆盖。
  - `tips.local.json`：用户自己的条目，任何脚本都不得覆盖或删除。
- 两个前端每次打开时重新读这两个文件，所以改完即生效，不需要文件监听。
- `tips.json` 不存在时，用前端自带的后备副本（构建时从 `content/tips.json` 复制，不许手工维护第二份）。
- 合并规则：先公开、后本机；本机条目 `id` 相同则覆盖公开条目；本机条目带 `"hidden": true` 时隐藏对应公开条目。
- 文件缺失、JSON 损坏或字段缺失时不崩溃：跳过坏条目，界面底部显示一行中文提示。

### 4.3 「未整理」分组

- 只读扫描 `~/.claude/skills/*/SKILL.md` 的 frontmatter（`name`、`description`），跳过没有 `SKILL.md` 的目录。
- 没有被任何条目的 `source.name` 引用的 skill，显示在「未整理」分组：标题用 skill 名，`copy` 为 `/<name>`，详情用它的 `description` 原文。
- 条目引用的 user-skill 在磁盘上已不存在时，该行变灰并标注“已不存在”。
- 「未整理」只在有内容时出现；扫描结果只在内存里，不写入任何文件。
- 内置 skill 在磁盘上没有稳定位置，不扫描；它们靠 `docs/refresh-tips-prompt.md` 手动维护。

## 5. 视觉规范（两个前端通用）

- **苹果风配色**：中性灰白为主，只有一个强调色，用在选中行和主按钮上。不用绿色，不用彩色分组标签，不用 emoji。
- 菜单栏应用的强调色用系统强调色（`Color.accentColor`），其余用系统语义色，不写死十六进制色值；浅色和深色都要检查。
- 侧边面板跟随 Claude 应用自身主题；强调色用宿主提供的主题色名，做不到蓝底白字时用宿主的选中样式，不要硬凑。
- 每行两行字：上面中文说明（主文字），下面英文原文（等宽字体、次要颜色）。行首一个中性色图标块。
- 分组靠图标和文字区分，不靠颜色。
- 状态文字只有三种：`已复制`、`已填入`、`已不存在`。

## 6. 侧边面板（`pane/`）

实现前先加载 `plugin-authoring` skill，按它的文件布局、类型检查和测试方式来做。可参考本机已有的同类 mod 写法（面板、斜杠命令、`$.fs` 读文件），但不要复制其中任何个人字符串。

**行为**
- `/tips` 打开或关闭面板，标题「速查」。
- 从上到下：搜索框、三个分组（各带标题和条数）、「未整理」（有内容时）。面板够高，三组直接往下排，不用分段切换。
- 点一行：调用 `$.prompt.fill({ text: tip.copy, mode: 'insert' })`。成功时该行显示 `已填入`；返回 `isFilled: false` 时改为写剪贴板并显示 `已复制`。
- 搜索：规则同 7.3。如果面板的元素表里没有可用的文本输入元素，改为 `/tips <关键词>` 过滤，并在面板顶部显示当前关键词。

**禁止**
- 不注册 `prompt.compose`、`prompt.submit` 的 `context`、`$.tool.register`、`$.agent`，不在 `session.start` 返回任何给模型看的内容。

**验收**
- `claude plugin validate pane` 通过，类型检查通过，`claude plugin test pane` 通过（至少覆盖：合并规则、搜索、点行后调用 `prompt.fill` 的参数、内容文件损坏时不抛错）。
- 实际加载后，`/tips` 能开关面板，点行后英文出现在输入框。
- **确认没有进入模型上下文**：对比加载前后一次新会话首个请求的 system 和 tools（transcript 里的 `api-request-shape`），不应多出与本 mod 有关的内容。如果注册 `/tips` 命令本身会进入模型上下文，改用不进入上下文的打开方式（例如输入框上方的一个小按钮），并在汇报里说明。

## 7. 菜单栏应用（`menubar/`）

### 7.1 技术选型

- 原生 Swift。本机环境：macOS 15.8.1，Intel（x86_64），Swift 6.1.2，只有 Command Line Tools，没有 Xcode。必须能用 `swift build` 构建，不依赖 Xcode 工程。
- 外壳用 AppKit：`NSStatusItem` + `NSPopover`（`.transient`），内容用 SwiftUI 经 `NSHostingController` 嵌入。不用 `MenuBarExtra`，因为全局快捷键呼出和复制后自动关闭都需要用代码开关浮层。
- 不显示 Dock 图标：`Info.plist` 里 `LSUIElement = true`。
- 全局快捷键用 Carbon 的 `RegisterEventHotKey`，默认 `⌥⌘K`，不需要辅助功能权限。
- Swift package 分两个 target：`TipsCore`（模型、读取、合并、搜索、skill 扫描，无界面，可测试）和 `ClaudeTipsMenuBar`（可执行，界面）。
- 不引入第三方依赖。不用 Astryx：它是 React 网页组件库（MIT，仍在 Beta），没有原生 macOS 版本；只借用它 `CommandPalette` 的结构（搜索框、分组、列表、底部按键提示）。

### 7.2 界面

- 浮层宽约 360pt。从上到下：搜索框（右端显示快捷键）、分段控件（直接说、斜杠命令、我的，各带条数；有内容时加「未整理」）、当前分组的列表、分隔线、一行按键提示。
- 详情层：按 `→` 或点行尾箭头进入，显示图标、中文标题、`detail`、英文原文（等宽字体的浅底块）、复制按钮；按 `←` 或点“返回”回到列表。

### 7.3 交互

| 操作 | 效果 |
|---|---|
| 点图标或按全局快捷键 | 打开浮层，光标在搜索框；再按一次关闭 |
| 直接打字 | 搜索；搜索时忽略分组，跨组显示结果 |
| `↑` `↓` | 移动选中行 |
| `↵` 或点击行 | 复制 `copy` 到剪贴板，该行显示 `已复制` 约 0.6 秒后浮层关闭 |
| `→` / `←` | 进入 / 退出详情层 |
| `⌘1` `⌘2` `⌘3` | 切换分组 |
| `esc` | 有搜索词时先清空，否则关闭 |

- 搜索规则：不区分大小写的子串匹配，范围是 `title`、`copy`、`keywords`。排序：`title` 开头匹配 > `title` 包含 > `keywords` 命中 > `copy` 命中；同级保持文件里的顺序。无结果时显示“没有找到，换个词试试”。
- 第一版不做自动粘贴（需要辅助功能权限），不做开机自启的代码（README 里写手动加入登录项的方法）。

### 7.4 打包

- `scripts/build-menubar-app.sh`：`swift build -c release`，组装 `build/Claude Tips.app`（`Contents/MacOS`、`Contents/Resources`、`Info.plist`），bundle id 用 `io.github.claude-tips.menubar`，最后做 ad-hoc 签名（`codesign --force --sign -`）。
- `build/` 加入 `.gitignore`。

### 7.5 验收

- `swift build` 和 `TipsCore` 的测试通过。Command Line Tools 下 XCTest 可能不可用：先试 Swift Testing，不行就写一个小的可执行测试 target，并在汇报里说明用了哪种。
- 打包出的 `.app` 能启动，菜单栏出现图标，浮层能打开；7.3 表里的每一项都实际试过。
- 浅色和深色各截一张图，与 `docs/design/menubar-target-light.png` 对照，说明差异。
- 做不到实际操作验证的项，要在汇报里逐条写明“未验证”，不能写成已通过。

## 8. 内容更新流程

- 改内置条目：编辑 `content/tips.json`，跑 `scripts/validate-tips.py`，再跑 `scripts/install-content.sh`。
- 改自己的条目：直接编辑 `~/.claude/claude-tips/tips.local.json`。
- Claude Code 升级后内置 skill 有变化：把 `docs/refresh-tips-prompt.md` 里的 prompt 贴给 Claude Code，让它对照当前会话的 skill 列表更新 `content/tips.json`（新增、改名、已移除的各列出来，由人确认后再改）。

## 9. 里程碑（按顺序做，每个做完单独提交）

| 里程碑 | 内容 | 完成标准 |
|---|---|---|
| M1 内容工具 | `scripts/validate-tips.py`（只用 Python 标准库）：检查 `id` 唯一、`group` 合法、必填字段齐全、`copy` 只含 ASCII、`title` 含中文；`scripts/install-content.sh` | 对现有 `content/tips.json` 校验通过；故意改坏一条能报错 |
| M2 侧边面板 | 第 6 节全部 | 第 6 节验收全部通过 |
| M3 菜单栏最小验证 | 状态栏图标加空浮层，`swift build` 通过，打包脚本能产出可启动的 `.app` | 图标出现，浮层能开关；如果 AppKit 外壳在本机工具链下走不通，停下来汇报，不要自行换技术路线 |
| M4 TipsCore | 模型、读取、合并、搜索、skill 扫描及测试 | 测试通过 |
| M5 菜单栏界面 | 第 7.2、7.3 节（快捷键除外） | 表里各项实际试过 |
| M6 全局快捷键与「未整理」 | `⌥⌘K`、「未整理」分组、变灰标注 | 实际试过 |
| M7 收尾 | README 补全（安装、使用、更新内容、登录项）、`docs/refresh-tips-prompt.md`、`.claude-plugin/marketplace.json` | 按 README 从零走一遍能装好两个前端 |

## 10. 尚未验证的假设

- 面板的元素表里有可用的文本输入元素（类型文件里出现过 `TextInput`，但没确认面板里能用）。
- 注册 `/tips` 斜杠命令不会进入模型上下文。
- 面板能用宿主主题色做出接近效果图的选中行。
- 只有 Command Line Tools 时，AppKit 加 SwiftUI 的可执行文件能正常构建和签名；Swift Testing 可用。
- `⌥⌘K` 没有被系统或其他常用应用占用。

每一条在对应里程碑里先验证；与假设不符时按本文件给出的退路处理，没有退路的停下来汇报。

## 11. 不做的事

- 不做 Notification Center 小组件、不做 Electron 或 Tauri 版本。
- 不做自动粘贴、不做云同步、不做使用统计。
- 不把扫描到的 skill 信息写回任何文件。
