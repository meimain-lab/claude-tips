import { describe, expect, test } from 'claude-code/testing'

import {
  buildRows,
  mergeTips,
  parseTipsFile,
  readFrontmatter,
  searchRows,
} from '../hooks/tips-core'
import type { Tip } from '../hooks/tips-core'
import { GROUP_ICONS, ICON_PATHS, firstSentence, iconFor, tileSvg } from '../hooks/icons'

const tip = (id: string, extra: Partial<Tip> = {}): Tip => ({
  id,
  group: 'say',
  title: `标题 ${id}`,
  copy: `copy ${id}`,
  detail: '',
  keywords: [],
  icon: '',
  sourceKind: 'builtin-skill',
  sourceName: id,
  ...extra,
})

describe('parseTipsFile', () => {
  test('a file that is not JSON is reported broken and does not throw', async () => {
    const parsed = parseTipsFile('{"version": 1, "tips": [')
    expect(parsed.isBroken).toBe(true)
    expect(parsed.tips).toEqual([])
  })

  test('a file without a tips list is reported broken', async () => {
    expect(parseTipsFile('{"version": 1}').isBroken).toBe(true)
    expect(parseTipsFile('[]').isBroken).toBe(true)
  })

  test('a missing file is empty, not broken', async () => {
    const parsed = parseTipsFile(undefined)
    expect(parsed.isBroken).toBe(false)
    expect(parsed.tips).toEqual([])
  })

  test('entries with missing fields are skipped and counted', async () => {
    const text = JSON.stringify({
      version: 1,
      tips: [
        { id: 'good', group: 'say', title: '好的', copy: 'Good.', source: { kind: 'x', name: 'y' } },
        { id: 'no-copy', group: 'say', title: '没有原文' },
        { id: 'bad-group', group: 'other', title: '分组不对', copy: 'x' },
        'not an object',
        { id: 'gone', hidden: true },
      ],
    })
    const parsed = parseTipsFile(text)
    expect(parsed.tips.map(one => one.id)).toEqual(['good'])
    expect(parsed.skipped).toBe(3)
    expect(parsed.hiddenIds).toEqual(['gone'])
  })
})

describe('mergeTips', () => {
  test('public first, local after; a local id replaces the public tip in place', async () => {
    const local = parseTipsFile(
      JSON.stringify({
        version: 1,
        tips: [
          { id: 'mine-1', group: 'mine', title: '我的一条', copy: '/mine-1' },
          { id: 'b', group: 'say', title: '本机改写', copy: 'Local b.' },
        ],
      }),
    )
    const merged = mergeTips([tip('a'), tip('b'), tip('c')], local)
    expect(merged.map(one => one.id)).toEqual(['a', 'b', 'c', 'mine-1'])
    expect(merged[1]?.copy).toBe('Local b.')
  })

  test('a local hidden entry removes the public tip', async () => {
    const local = parseTipsFile(JSON.stringify({ version: 1, tips: [{ id: 'b', hidden: true }] }))
    expect(mergeTips([tip('a'), tip('b')], local).map(one => one.id)).toEqual(['a'])
  })
})

describe('searchRows', () => {
  const rows = [
    tip('copy-hit', { title: '其他', copy: 'Make a chart now' }),
    tip('keyword-hit', { title: '画个东西', keywords: ['Chart'] }),
    tip('title-contains', { title: '数据 chart 图' }),
    tip('title-prefix', { title: 'Chart 优先' }),
    tip('no-hit', { title: '无关' }),
  ]

  test('ranks title prefix, title contains, keyword, copy; ignores case', async () => {
    expect(searchRows(rows, 'CHART').map(one => one.id)).toEqual([
      'title-prefix',
      'title-contains',
      'keyword-hit',
      'copy-hit',
    ])
  })

  test('keeps file order within a rank and returns all rows for an empty query', async () => {
    const same = [tip('one', { title: '图表一' }), tip('two', { title: '图表二' })]
    expect(searchRows(same, '图表').map(one => one.id)).toEqual(['one', 'two'])
    expect(searchRows(rows, '  ').length).toBe(rows.length)
  })

  test('finds Chinese keywords', async () => {
    expect(searchRows(rows, '画个').map(one => one.id)).toEqual(['keyword-hit'])
  })
})

describe('readFrontmatter and buildRows', () => {
  test('reads plain, quoted and folded values', async () => {
    expect(readFrontmatter('---\nname: alpha\ndescription: "Does a thing"\n---\nbody')).toEqual({
      name: 'alpha',
      description: 'Does a thing',
    })
    expect(readFrontmatter('---\nname: beta\ndescription: >\n  First line\n  second line\n---\n'))
      .toEqual({ name: 'beta', description: 'First line second line' })
    expect(readFrontmatter('no frontmatter')).toEqual({})
  })

  test('unreferenced skills go to 未整理; a missing user skill is marked', async () => {
    const tips = [
      tip('kept', { sourceKind: 'user-skill', sourceName: 'kept' }),
      tip('gone', { sourceKind: 'user-skill', sourceName: 'gone' }),
    ]
    const { rows, unsorted } = buildRows(tips, [
      { dirName: 'kept', name: 'kept', description: '' },
      { dirName: 'new-one', name: 'new-one', description: 'A new skill' },
    ])
    expect(rows.map(row => row.isMissing)).toEqual([false, true])
    expect(unsorted.map(row => [row.title, row.copy, row.detail])).toEqual([
      ['new-one', '/new-one', 'A new skill'],
    ])
  })

  test('without a skill scan nothing is marked missing', async () => {
    const { rows, unsorted } = buildRows([tip('x', { sourceKind: 'user-skill' })], undefined)
    expect(rows[0]?.isMissing).toBe(false)
    expect(unsorted).toEqual([])
  })
})

describe('icons', () => {
  // The names content/tips.json and the example local file use today, plus
  // four common extras. scripts/validate-tips.py checks the real files.
  const CONTENT_ICONS = [
    'arrow.down.right.and.arrow.up.left', 'arrow.triangle.2.circlepath', 'calendar.badge.clock',
    'chart.bar', 'checkmark.shield', 'doc.text', 'ladybug', 'link', 'lock.open', 'play',
    'puzzlepiece', 'repeat', 'wand.and.stars', 'star',
    'note.text', 'arrow.triangle.branch', 'tag', 'paperplane',
  ]

  test('every icon name the content uses has a drawing', () => {
    const missing = CONTENT_ICONS.filter(name => !(name in ICON_PATHS))
    expect(missing).toEqual([])
  })

  test('an unknown icon name falls back to the group icon', () => {
    expect(iconFor('no.such.symbol', 'slash')).toBe(GROUP_ICONS.slash)
    expect(iconFor('', 'unsorted')).toBe(GROUP_ICONS.unsorted)
    expect(iconFor('chart.bar', 'say')).toBe('chart.bar')
    for (const name of Object.values(GROUP_ICONS)) expect(name in ICON_PATHS).toBe(true)
  })

  test('the tile is one fixed 32 px image', () => {
    const svg = tileSvg('chart.bar', false)
    expect(svg).toContain('width="32" height="32"')
    expect(svg).toContain('<rect')
  })

  test('firstSentence keeps the first sentence on one line', () => {
    expect(firstSentence('Does one thing. Then more.')).toBe('Does one thing.')
    expect(firstSentence('先做这个。再做那个。')).toBe('先做这个。')
    expect(firstSentence('No full stop\nat all')).toBe('No full stop at all')
    expect(firstSentence('Version 2.1 works. Next.')).toBe('Version 2.1 works.')
  })
})
