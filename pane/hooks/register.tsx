// claude-tips pane: a local cheat sheet beside the chat.
// Purely local UI: it registers one slash command and one pane, reads files,
// and fills the prompt box on a press. It adds nothing to the model's context.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, UiPressArgument } from 'claude-code'

import type { Feedback, Library } from '../types'
import { GROUP_GLYPHS, GROUP_ICONS, firstSentence, glyphSvg, iconFor, tileSvg } from './icons'
import type { IconGroup } from './icons'
import {
  GROUPS,
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
// The one row whose detail is open, by id; null when every row is closed.
const expanded = atom({ plugin: 'tips-pane', key: 'expanded' } as const, null as string | null)

/** Text glyphs for the detail toggle: closed and open look different, no emoji. */
const TOGGLE_CLOSED = '\u203A'
const TOGGLE_OPEN = '\u2304'
// No-break spaces widen the toggle's press target on graphical surfaces,
// where a lone glyph is only a few points wide; ordinary spaces collapse.
const TOGGLE_PAD = '\u00A0\u00A0'

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
  await update($, expanded, () => null)
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
    const elements = $.ui.resolve(e)
    const { Box, Text, Button, Input } = elements
    // The desktop and other graphical surfaces draw Svg; the terminal does not.
    const Svg = 'Svg' in elements ? elements.Svg : undefined
    const data = (await read($, library)) ?? (await loadLibrary($))
    const keyword = await read($, query)
    const shown = await read($, feedback)
    const openId = await read($, expanded)
    const isGraphical = Svg !== undefined
    const unsortedIds = new Set(data.unsorted.map(row => row.id))
    const groupOf = (row: Row): IconGroup => (unsortedIds.has(row.id) ? 'unsorted' : row.group)

    // Fixed-size icon block that never shrinks: one 32 px image on graphical
    // surfaces, a fixed-width cell with the group glyph on the terminal.
    const drawTile = (row: Row, isActive: boolean) => (
      <Box key={`icon-${row.id}`} flexShrink={0} width={isGraphical ? undefined : 3}>
        {Svg ? (
          <Svg
            source={tileSvg(iconFor(row.icon, groupOf(row)), isActive)}
            alt={iconFor(row.icon, groupOf(row))}
            width={32}
            height={32}
          />
        ) : (
          <Text dimColor>{GROUP_GLYPHS[groupOf(row)]}</Text>
        )}
      </Box>
    )

    const drawRow = (row: Row) => {
      const isActive = shown?.id === row.id
      const status = isActive ? shown.label : row.isMissing ? '已不存在' : ''
      const isUnsorted = unsortedIds.has(row.id)
      const description = isUnsorted ? firstSentence(row.detail) : ''
      const second = description !== '' ? description : row.copy
      const hasDetail = row.detail.trim() !== ''
      const isOpen = hasDetail && openId === row.id
      const strong = isActive ? '#FFFFFF' : undefined
      return (
        <Box
          key={`row-${row.id}`}
          flexDirection="row"
          alignItems="center"
          gap={isGraphical ? 'sm' : 1}
          paddingX={isGraphical ? 'sm' : 0}
          paddingY={isGraphical ? 'xs' : 0}
          backgroundColor={isActive ? 'suggestion' : undefined}
          hover={isActive ? undefined : { backgroundColor: 'rgba(142,142,147,0.14)' }}
        >
          {drawTile(row, isActive)}
          <Box flexDirection="column" flexGrow={1} flexShrink={1} minWidth={0}>
            <Button
              key={`tip-${row.id}`}
              plain
              dimColor={row.isMissing && !isActive}
              onPress={press => useTip($, row, press.surface)}
            >
              <Text color={strong} dimColor={row.isMissing && !isActive} wrap="truncate-end">
                {row.title}
              </Text>
            </Button>
            {/* The second line is a Button too, so it fills the same text; a
                Button ignores mono, so the English is drawn proportional. */}
            <Button
              key={`copy-${row.id}`}
              plain
              dimColor={!isActive}
              onPress={press => useTip($, row, press.surface)}
            >
              <Text size="footnote" color={strong} dimColor={!isActive} wrap="truncate-end">
                {second}
              </Text>
            </Button>
            {isOpen && (
              // A plain Button's label sits about 6 pt in; xs lines the detail up with it.
              <Box key={`detail-${row.id}`} paddingLeft={isGraphical ? 'xs' : 0} paddingTop={isGraphical ? 'xs' : 0}>
                <Text size="footnote" color={strong} dimColor={!isActive} wrap="wrap">
                  {row.detail}
                </Text>
              </Box>
            )}
          </Box>
          {status !== '' && (
            <Box key={`status-${row.id}`} flexShrink={0}>
              <Text size="footnote" color={strong} dimColor={!isActive}>
                {status}
              </Text>
            </Box>
          )}
          {hasDetail && (
            <Box key={`toggle-box-${row.id}`} flexShrink={0}>
              <Button
                key={`toggle-${row.id}`}
                plain
                dimColor={!isActive}
                onPress={() => {
                  void update($, expanded, current => (current === row.id ? null : row.id))
                }}
              >
                <Text color={strong} dimColor={!isActive}>
                  {isGraphical
                    ? `${TOGGLE_PAD}${isOpen ? TOGGLE_OPEN : TOGGLE_CLOSED}${TOGGLE_PAD}`
                    : isOpen
                      ? TOGGLE_OPEN
                      : TOGGLE_CLOSED}
                </Text>
              </Button>
            </Box>
          )}
        </Box>
      )
    }

    const drawSection = (key: string, title: string, icon: IconGroup | undefined, rows: Row[]) => (
      <Box key={`section-${key}`} flexDirection="column" marginTop={isGraphical ? 'md' : 1}>
        <Box key={`heading-${key}`} flexDirection="row" alignItems="center" gap={isGraphical ? 'sm' : 1} paddingX={isGraphical ? 'sm' : 0} paddingY={isGraphical ? 'xs' : 0}>
          {icon !== undefined &&
            (Svg ? (
              <Svg source={glyphSvg(GROUP_ICONS[icon])} alt={GROUP_ICONS[icon]} width={16} height={16} />
            ) : (
              <Box width={3} flexShrink={0}>
                <Text dimColor>{GROUP_GLYPHS[icon]}</Text>
              </Box>
            ))}
          <Text size="footnote" weight="semibold" dimColor>
            {title}
          </Text>
          <Text size="footnote" dimColor>
            {String(rows.length)}
          </Text>
        </Box>
        {rows.map(drawRow)}
      </Box>
    )

    // An empty alt draws nothing on the desktop, so every Svg names its icon.
    const search = (
      <Box key="search-box" width="100%">
        <Input
        key="search"
        placeholder="搜索：画图、定时"
        value={keyword}
        submitLabel="搜"
        onInput={value => {
          void update($, query, () => value)
          void update($, expanded, () => null)
        }}
        onSubmit={value => {
          void update($, query, () => value)
          void update($, expanded, () => null)
        }}
        />
      </Box>
    )

    const body = (() => {
      if (keyword.trim() !== '') {
        const found = searchRows([...data.rows, ...data.unsorted], keyword)
        if (found.length === 0) {
          return (
            <Box marginTop={1}>
              <Text dimColor>没有找到，换个词试试</Text>
            </Box>
          )
        }
        return drawSection('results', '搜索结果', undefined, found)
      }
      return (
        <Box flexDirection="column">
          {GROUPS.map(group =>
            drawSection(
              group.id,
              group.title,
              group.id,
              data.rows.filter(row => row.group === group.id),
            ),
          )}
          {data.unsorted.length > 0 && drawSection('unsorted', '未整理', 'unsorted', data.unsorted)}
        </Box>
      )
    })()

    return (
      <Box flexDirection="column" paddingX={isGraphical ? 0 : 1}>
        {search}
        {body}
        {data.notices.length > 0 && (
          <Box flexDirection="column" marginTop={1}>
            {data.notices.map(line => (
              <Text size="footnote" dimColor>
                {line}
              </Text>
            ))}
          </Box>
        )}
      </Box>
    )
  })
}
