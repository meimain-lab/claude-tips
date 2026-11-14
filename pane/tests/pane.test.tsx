import { expect, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

const HOME = '/home/tester'
const RUNTIME = `${HOME}/.claude/claude-tips`
const SKILLS = `${HOME}/.claude/skills`

const PANE = {
  plugin: 'tips-pane',
  component: 'Pane',
  requestId: 'claude-tips',
  props: {
    title: '速查',
    isFocused: false,
    bodyColumns: 48,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 60 },
    view: {},
  },
} as const

const PUBLIC = JSON.stringify({
  version: 1,
  tips: [
    {
      id: 'chart-data',
      group: 'say',
      title: '把数据画成图',
      copy: 'Turn this data into a chart.',
      detail: '画图的详细说明。',
      keywords: ['图表', 'chart'],
      icon: 'chart.bar',
      source: { kind: 'builtin-skill', name: 'dataviz' },
    },
    {
      id: 'compact',
      group: 'slash',
      title: '对话太长时压缩',
      copy: '/compact',
      detail: '压缩的详细说明。',
      keywords: ['压缩'],
      icon: 'arrow',
      source: { kind: 'builtin-command', name: 'compact' },
    },
    {
      id: 'hidden-one',
      group: 'say',
      title: '会被隐藏的一条',
      copy: 'Hide me.',
      detail: '',
      keywords: [],
      icon: '',
      source: { kind: 'builtin-skill', name: 'hidden-one' },
    },
  ],
})

const LOCAL = JSON.stringify({
  version: 1,
  tips: [
    { id: 'hidden-one', hidden: true },
    {
      id: 'kept-skill',
      group: 'mine',
      title: '我的技能',
      copy: '/kept-skill',
      detail: '',
      keywords: [],
      icon: 'star',
      source: { kind: 'user-skill', name: 'kept-skill' },
    },
    {
      id: 'gone-skill',
      group: 'mine',
      title: '已经删掉的技能',
      copy: '/gone-skill',
      detail: '',
      keywords: [],
      icon: 'star',
      source: { kind: 'user-skill', name: 'gone-skill' },
    },
  ],
})

const BUNDLED = JSON.stringify({
  version: 1,
  tips: [
    {
      id: 'bundled-only',
      group: 'say',
      title: '自带副本里的一条',
      copy: 'From the bundled copy.',
      detail: '',
      keywords: [],
      icon: '',
      source: { kind: 'builtin-skill', name: 'bundled-only' },
    },
  ],
})

type Files = Record<string, string>

const RUN = {
  origin: { kind: 'composer' },
  presentation: { isFullscreen: false, columns: 120 },
} as const

const defaultFiles = (): Files => ({
  [`${RUNTIME}/tips.json`]: PUBLIC,
  [`${RUNTIME}/tips.local.json`]: LOCAL,
  [`${SKILLS}/kept-skill/SKILL.md`]: '---\nname: kept-skill\ndescription: Kept.\n---\n',
  [`${SKILLS}/loose-skill/SKILL.md`]:
    '---\nname: loose-skill\ndescription: Not in any tip yet. It also does a second thing.\n---\n',
})

/** Stands in for the engine's files, environment and timers. */
function engine(on: Parameters<TestBody>[1], files: Files) {
  on('env.get', () => ({ value: HOME }))
  on('fs.read', (_, e) => {
    if (e.path.endsWith('/assets/tips.json')) return { value: BUNDLED }
    const text = files[e.path]
    return text === undefined ? { deny: 'ENOENT' } : { value: text }
  })
  on('fs.list', (_, e) => {
    if (e.path !== SKILLS) return { deny: 'ENOENT' }
    return {
      value: ['kept-skill', 'loose-skill', 'empty-dir'].map(name => ({
        name,
        kind: 'dir' as const,
        size: 0,
        mtimeMs: 0,
        isLink: false,
      })),
    }
  })
  // Timers never fire in these tests, so a row's status stays up to be read.
  on('clock.after', () => ({ deny: 'timers are held in tests' }))
}

/** A section header's count, drawn as its own Text right after the title. */
async function headerCount(ui: { find: (q: { key: string }) => Promise<{ text?: string } | undefined> }, key: string) {
  return (await ui.find({ key: `heading-${key}` }))?.text
}

test('the pane lists merged groups, 未整理 and marks a missing skill', async ($, on) => {
  engine(on, defaultFiles())
  for (const surface of ['desktop', 'terminal'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await headerCount(ui, 'say')).toMatch(/直接说\s*1/)
    expect(await headerCount(ui, 'slash')).toMatch(/斜杠命令\s*1/)
    expect(await headerCount(ui, 'mine')).toMatch(/我的\s*2/)
    expect(await headerCount(ui, 'unsorted')).toMatch(/未整理\s*1/)
    expect(await ui.find({ type: 'Text', text: /会被隐藏/ })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: '已不存在' })).toBeDefined()
    await ui.unmount()
  }
})

test('each row is two lines, and both lines are buttons', async ($, on) => {
  engine(on, defaultFiles())
  for (const surface of ['desktop', 'terminal'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    const button = await ui.find({ key: 'tip-chart-data' })
    expect(button?.text).toBe('把数据画成图')
    const english = await ui.find({ key: 'copy-chart-data' })
    expect(english?.type).toBe('Button')
    expect(english?.text).toBe('Turn this data into a chart.')
    // The icon block is its own fixed element, not part of the button.
    expect(await ui.find({ key: 'icon-chart-data' })).toBeDefined()
    await ui.unmount()
  }
})

test('an 未整理 row shows the skill description under its name, and fills /name', async ($, on) => {
  engine(on, defaultFiles())
  const fills: string[] = []
  on('prompt.fill', (_, e) => {
    fills.push(e.text)
    return { isFilled: true, draft: e.text, cursor: e.text.length }
  })
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect((await ui.find({ key: 'tip-unsorted-loose-skill' }))?.text).toBe('loose-skill')
  expect((await ui.find({ key: 'copy-unsorted-loose-skill' }))?.text).toBe('Not in any tip yet.')
  expect(await ui.find({ type: 'Text', text: '/loose-skill' })).toBeUndefined()
  await ui.press({ key: 'tip-unsorted-loose-skill' })
  await ui.press({ key: 'copy-unsorted-loose-skill' })
  expect(fills).toEqual(['/loose-skill', '/loose-skill'])
  // Its detail is the whole description, not just the first sentence.
  await ui.press({ key: 'toggle-unsorted-loose-skill' })
  expect((await ui.find({ key: 'detail-unsorted-loose-skill' }))?.text).toBe(
    'Not in any tip yet. It also does a second thing.',
  )
  await ui.unmount()
})

test('pressing a row fills the prompt box with its English text', async ($, on) => {
  engine(on, defaultFiles())
  const fills: unknown[] = []
  on('prompt.fill', (_, e) => {
    fills.push({ text: e.text, mode: e.mode })
    return { isFilled: true, draft: e.text, cursor: e.text.length }
  })
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  await ui.press({ key: 'tip-chart-data' })
  expect(fills).toEqual([{ text: 'Turn this data into a chart.', mode: 'insert' }])
  expect(await ui.find({ type: 'Text', text: '已填入' })).toBeDefined()
  await ui.unmount()
})

test('pressing the English line fills the same text and shows 已填入', async ($, on) => {
  engine(on, defaultFiles())
  const fills: string[] = []
  on('prompt.fill', (_, e) => {
    fills.push(e.text)
    return { isFilled: true, draft: e.text, cursor: e.text.length }
  })
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  await ui.press({ key: 'copy-compact' })
  expect(fills).toEqual(['/compact'])
  expect(await ui.find({ key: 'status-compact' })).toBeDefined()
  expect((await ui.find({ key: 'status-compact' }))?.text).toBe('已填入')
  await ui.unmount()
})

test('the toggle opens and closes a row detail, one row at a time', async ($, on) => {
  engine(on, defaultFiles())
  for (const surface of ['desktop', 'terminal'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ key: 'detail-chart-data' })).toBeUndefined()
    expect((await ui.find({ key: 'toggle-chart-data' }))?.text?.trim()).toBe('\u203A')
    await ui.press({ key: 'toggle-chart-data' })
    expect((await ui.find({ key: 'detail-chart-data' }))?.text).toBe('画图的详细说明。')
    expect((await ui.find({ key: 'toggle-chart-data' }))?.text?.trim()).toBe('\u2304')
    // Opening another row closes the first.
    await ui.press({ key: 'toggle-compact' })
    expect(await ui.find({ key: 'detail-chart-data' })).toBeUndefined()
    expect((await ui.find({ key: 'detail-compact' }))?.text).toBe('压缩的详细说明。')
    // Pressing the open row's toggle again closes it.
    await ui.press({ key: 'toggle-compact' })
    expect(await ui.find({ key: 'detail-compact' })).toBeUndefined()
    // A row with no detail has no toggle.
    expect(await ui.find({ key: 'toggle-kept-skill' })).toBeUndefined()
    await ui.unmount()
  }
})

test('the status text comes before the toggle', async ($, on) => {
  engine(on, defaultFiles())
  on('prompt.fill', (_, e) => ({ isFilled: true, draft: e.text, cursor: e.text.length }))
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  await ui.press({ key: 'tip-chart-data' })
  const row = await ui.find({ key: 'row-chart-data' })
  expect(row?.text).toMatch(/已填入\s*\u203A\s*$/)
  await ui.unmount()
})

test('a search change closes the open detail', async ($, on) => {
  engine(on, defaultFiles())
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  await ui.press({ key: 'toggle-chart-data' })
  expect(await ui.find({ key: 'detail-chart-data' })).toBeDefined()
  await ui.input({ key: 'search', text: 'chart' })
  expect(await ui.find({ key: 'row-chart-data' })).toBeDefined()
  expect(await ui.find({ key: 'detail-chart-data' })).toBeUndefined()
  await ui.unmount()
})

test('when no prompt box takes the text it is copied instead', async ($, on) => {
  engine(on, defaultFiles())
  const copies: string[] = []
  on('prompt.fill', () => ({ isFilled: false, reason: 'no_composer', draft: '', cursor: 0 }))
  on('ui.copy', (_, e) => {
    copies.push(e.text)
    return { value: { isCopied: true } }
  })
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  await ui.press({ key: 'tip-compact' })
  expect(copies).toEqual(['/compact'])
  expect(await ui.find({ type: 'Text', text: '已复制' })).toBeDefined()
  await ui.unmount()
})

test('typing in the search box filters across groups', async ($, on) => {
  engine(on, defaultFiles())
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  await ui.input({ key: 'search', text: 'CHART' })
  expect(await headerCount(ui, 'results')).toMatch(/搜索结果\s*1/)
  expect(await ui.find({ type: 'Text', text: '/compact' })).toBeUndefined()
  await ui.input({ key: 'search', text: '没有这个词' })
  expect(await ui.find({ type: 'Text', text: '没有找到，换个词试试' })).toBeDefined()
  await ui.unmount()
})

test('a broken tips.json falls back to the bundled copy without throwing', async ($, on) => {
  const files = defaultFiles()
  files[`${RUNTIME}/tips.json`] = '{"version": 1, "tips": ['
  files[`${RUNTIME}/tips.local.json`] = 'not json at all'
  engine(on, files)
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: '自带副本里的一条' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /tips\.json 无法读取/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /tips\.local\.json 不是有效的 JSON/ })).toBeDefined()
  await ui.unmount()
})

test('a missing runtime folder uses the bundled copy quietly', async ($, on) => {
  engine(on, {})
  const ui = await $.ui.mount({ ...PANE, surface: 'desktop' })
  expect(await ui.find({ type: 'Text', text: '自带副本里的一条' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /无法读取/ })).toBeUndefined()
  await ui.unmount()
})

test('/tips opens the pane, and closes it when open', async ($, on) => {
  engine(on, defaultFiles())
  const open = new Set<string>()
  on('command.register', () => ({ value: { command: 'tips' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('ui.open', (_, e) => {
    open.add(e.id)
    return { value: { isPlaced: true } }
  })
  on('ui.close', (_, e) => {
    open.delete(e.id)
    return { value: undefined }
  })
  on('ui.panes', () => ({
    value: [...open].map(id => ({ id, title: '速查', isShown: true, isFocused: false, isPlaced: true })),
  }))
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })
  const first = await $.command.run({ ...RUN, command: 'tips', args: '' })
  expect(first.text).toBeUndefined()
  expect(open.has('claude-tips')).toBe(true)
  await $.command.run({ ...RUN, command: 'tips', args: '' })
  expect(open.has('claude-tips')).toBe(false)
})
