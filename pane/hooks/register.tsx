// claude-tips pane: a local cheat sheet beside the chat.
// Purely local UI: it registers one slash command and one pane, reads files,
// and fills the prompt box on a press. It adds nothing to the model's context.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, UiPressArgument } from 'claude-code'

import type { Feedback, Library } from '../types'
import {
  GROUPS,
  GROUP_GLYPHS,
  buildRows,
  mergeTips,
  parseTipsFile,
  readFrontmatter,
  searchRows,
} from './tips-core'
import type { Row, SkillInfo } from './tips-core'

const PANE_ID = 'claude-tips'
const PANE_TITLE = '速查'
const FEEDBACK_MS = 1600

// Change a tag when that value's fields change: it declines what an earlier
// version stored, which outlives a reload.
const library = atom({ plugin: 'tips-pane', key: 'library' } as const, null, {
  shape: 'library-1',
})
const query = atom({ plugin: 'tips-pane', key: 'query' } as const, '')
const feedback = atom({ plugin: 'tips-pane', key: 'feedback' } as const, null, {
  shape: 'feedback-1',
})

async function readOptional($: EngineInterface, path: string): Promise<string | undefined> {
  try {
    return await $.fs.read(path)
  } catch {
    return undefined
  }
}

/** Read-only scan of ~/.claude/skills/*\/SKILL.md; undefined when the folder is unreadable. */
async function scanSkills($: EngineInterface, home: string): Promise<SkillInfo[] | undefined> {
  const folder = `${home}/.claude/skills`
  let entries
  try {
    entries = await $.fs.list(folder)
  } catch {
    return undefined
  }
  const skills: SkillInfo[] = []
  for (const entry of entries) {
    if (entry.kind === 'file' || entry.name.startsWith('.')) continue
    const text = await readOptional($, `${folder}/${entry.name}/SKILL.md`)
    if (text === undefined) continue
    const meta = readFrontmatter(text)
    skills.push({
      dirName: entry.name,
      name: meta.name ?? entry.name,
      description: meta.description ?? '',
    })
  }
  return skills
}

/** Reads both content files and the skill folder fresh. Never throws. */
export async function loadLibrary($: EngineInterface): Promise<Library> {
  const notices: string[] = []
  const home = (await $.env.get('HOME')) ?? ''
  const runtimeDir = `${home}/.claude/claude-tips`

  let publicFile = parseTipsFile(await readOptional($, `${runtimeDir}/tips.json`))
  const runtimeMissing = publicFile.tips.length === 0 && !publicFile.isBroken
  if (publicFile.isBroken || runtimeMissing) {
    if (publicFile.isBroken) notices.push('tips.json 无法读取，已改用面板自带的副本')
    publicFile = parseTipsFile(await readOptional($, `${$.plugin.root}/assets/tips.json`))
  }
  const localFile = parseTipsFile(await readOptional($, `${runtimeDir}/tips.local.json`))
  if (localFile.isBroken) notices.push('tips.local.json 不是有效的 JSON，已忽略')

  const skipped = publicFile.skipped + localFile.skipped
  if (skipped > 0) notices.push(`跳过 ${skipped} 条字段不全的条目`)

  const skills = await scanSkills($, home)
  const { rows, unsorted } = buildRows(mergeTips(publicFile.tips, localFile), skills)
  return { rows, unsorted, notices }
}

async function openPane($: EngineInterface, keyword: string): Promise<void> {
  await update($, library, () => null)
  const loaded = await loadLibrary($)
  await update($, library, () => loaded)
  await update($, query, () => keyword)
  await update($, feedback, () => null)
  await $.ui.open({ id: PANE_ID, title: PANE_TITLE })
}

/** Fills the prompt box with the tip's English text; copies it when no box takes it. */
export async function useTip(
  $: EngineInterface,
  row: Row,
  surface: UiPressArgument['surface'],
): Promise<void> {
  const filled = await $.prompt.fill({ text: row.copy, mode: 'insert' })
  let label: Feedback['label'] = '已填入'
  if (!filled.isFilled) {
    await $.ui.copy({ text: row.copy, surface })
    label = '已复制'
  }
  const shown: Feedback = { id: row.id, label }
  await update($, feedback, () => shown)
  $.clock.after(FEEDBACK_MS, () => {
    void update($, feedback, current => (current?.id === shown.id ? null : current))
  })
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'tips',
      description: '打开或关闭速查面板',
      argumentHint: '[关键词]',
      immediate: true,
    })
    return next(e)
  })

  on('command.run', { command: 'tips' }, async ($, e) => {
    try {
      const keyword = e.args.trim()
      const isOpen = (await $.ui.panes()).some(pane => pane.id === PANE_ID)
      if (isOpen && keyword === '') {
        await $.ui.close({ id: PANE_ID })
      } else {
        await openPane($, keyword)
      }
    } catch {
      $.ui.toast('速查面板打开失败')
    }
    // No text: nothing for the transcript or the model.
    return {}
  })

  on('ui.render', { component: 'Pane', requestId: PANE_ID }, async ($, e) => {
    const { Box, Text, Button, Input } = $.ui.resolve(e)
    const data = (await read($, library)) ?? (await loadLibrary($))
    const keyword = await read($, query)
    const shown = await read($, feedback)

    const drawRow = (row: Row, glyph: string) => {
      const status = row.isMissing ? '已不存在' : shown?.id === row.id ? shown.label : ''
      const isActive = shown?.id === row.id
      return (
        <Box key={`row-${row.id}`} flexDirection="row" gap={1} alignItems="flex-start">
          <Box
            width={3}
            justifyContent="center"
            backgroundColor={isActive ? 'suggestion' : 'subtle'}
          >
            <Text color={isActive ? 'inverseText' : 'text'}>{glyph}</Text>
          </Box>
          <Box flexDirection="column" flexGrow={1} flexShrink={1}>
            <Button
              key={`tip-${row.id}`}
              plain
              dimColor={row.isMissing}
              onPress={press => useTip($, row, press.surface)}
            >
              <Text dimColor={row.isMissing}>{row.title}</Text>
              {'\n'}
              <Text mono dimColor>
                {row.copy}
              </Text>
            </Button>
          </Box>
          {status !== '' && (
            <Text color={isActive ? 'suggestion' : undefined} dimColor={!isActive}>
              {status}
            </Text>
          )}
        </Box>
      )
    }

    const drawSection = (key: string, title: string, rows: Row[], glyph: (row: Row) => string) => (
      <Box key={`section-${key}`} flexDirection="column" gap={1} marginTop={1}>
        <Text dimColor bold>
          {title} · {rows.length}
        </Text>
        {rows.map(row => drawRow(row, glyph(row)))}
      </Box>
    )

    const search = (
      <Input
        key="search"
        placeholder="搜索：中文或英文都行"
        value={keyword}
        submitLabel="搜索"
        onInput={value => {
          void update($, query, () => value)
        }}
        onSubmit={value => {
          void update($, query, () => value)
        }}
      />
    )

    const body = (() => {
      if (keyword.trim() !== '') {
        const found = searchRows([...data.rows, ...data.unsorted], keyword)
        if (found.length === 0) {
          return <Text dimColor>没有找到，换个词试试</Text>
        }
        const unsortedIds = new Set(data.unsorted.map(row => row.id))
        return drawSection('results', '搜索结果', found, row =>
          unsortedIds.has(row.id) ? GROUP_GLYPHS.unsorted : GROUP_GLYPHS[row.group],
        )
      }
      return (
        <Box flexDirection="column">
          {GROUPS.map(group =>
            drawSection(
              group.id,
              group.title,
              data.rows.filter(row => row.group === group.id),
              () => GROUP_GLYPHS[group.id],
            ),
          )}
          {data.unsorted.length > 0 &&
            drawSection('unsorted', '未整理', data.unsorted, () => GROUP_GLYPHS.unsorted)}
        </Box>
      )
    })()

    return (
      <Box flexDirection="column" paddingX={1}>
        {search}
        {body}
        {data.notices.length > 0 && (
          <Box flexDirection="column" marginTop={1}>
            {data.notices.map(line => (
              <Text dimColor>{line}</Text>
            ))}
          </Box>
        )}
      </Box>
    )
  })
}
