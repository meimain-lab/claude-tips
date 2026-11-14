# claude-tips

Claude Code 速查表：不用记功能名，查一下“该说什么、该输入什么”。

每条提示有中文说明和一句可以直接用的英文原文（美式口语或斜杠命令）。

| 前端 | 说明 | 状态 |
|---|---|---|
| 侧边面板 | Claude 桌面应用里聊天区旁边的面板，点一行把英文填进输入框 | 开发中 |
| 菜单栏应用 | macOS 菜单栏图标，点开搜索，回车复制 | 开发中 |

两个前端都是纯本地界面：只读本机文件，不向 Claude 的会话注入任何内容。

- 内容文件：[content/tips.json](content/tips.json)
- 加自己的条目：把 [content/tips.local.example.json](content/tips.local.example.json) 复制到 `~/.claude/claude-tips/tips.local.json` 再修改
- 实施计划：[docs/implementation-plan.md](docs/implementation-plan.md)

## 许可

MIT，见 [LICENSE](LICENSE)。
