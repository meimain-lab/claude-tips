# 维护用 prompt：对照当前 Claude Code 更新内置条目

Claude Code 升级后，内置的 skill、工具和斜杠命令可能有新增、改名或移除。内置 skill 在磁盘上没有固定位置，前端扫描不到，所以要靠下面这段 prompt 手动核对。

用法：在本仓库里开一个新的 Claude Code 会话，把下面代码块里的英文原样贴进去发送。它会先列出差异，等你确认后才改文件。

```text
You are maintaining the cheat sheet in this repository. The source of truth is content/tips.json; read it first, together with the field rules in docs/implementation-plan.md section 4.1.

Compare every entry whose source.kind is builtin-skill, builtin-tool or builtin-command against what this session actually offers: the skills listed in your system context, the tools you can call (including deferred ones), and the built-in slash commands of this Claude Code version.

Report, without editing anything yet:
1. Removed: entries whose source.name no longer exists.
2. Renamed: entries whose skill, tool or command now has a different name, with the old and new name.
3. Changed: entries whose behaviour changed enough that the Chinese title, detail or the English copy is now wrong.
4. New: built-in skills, tools or commands that a non-expert would want but have no entry yet. Suggest at most five, each with group, a Chinese title, an English copy line, a Chinese detail and keywords.

Ignore skills that come from the user's own ~/.claude/skills folder or from installed plugins; those belong in the user's tips.local.json, not here.

Then stop and wait for me to say which items to apply. When I confirm:
- Edit content/tips.json only. Keep ids kebab-case and stable; keep copy ASCII-only and natural American English; keep title one line of Simplified Chinese; do not add personal or employer-specific content.
- Run scripts/validate-tips.py and fix anything it reports. If it says pane/assets/tips.json is out of date, run scripts/sync-pane-fallback.sh.
- Run scripts/install-content.sh.
- Show me the diff of content/tips.json and do not commit unless I ask.
```

## 跑完之后

- 菜单栏应用里的后备副本只在下次运行 `scripts/build-menubar-app.sh` 时更新；平时应用读的是 `~/.claude/claude-tips/tips.json`，装好内容就生效。
- 如果只是想改自己的条目，不需要这段 prompt，直接编辑 `~/.claude/claude-tips/tips.local.json`。
