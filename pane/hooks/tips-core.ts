// Pure logic for the claude-tips pane: parsing, merging, searching and the
// skill scan's frontmatter reader. No engine calls here, so tests can drive it.

import type { GroupId, Language, Notice, Row, Tip } from '../types'

export type { GroupId, Language, Notice, Row, Tip }

export type SkillInfo = { dirName: string; name: string; description: string }

export type ParsedFile = {
  tips: Tip[]
  hiddenIds: string[]
  skipped: number
  isBroken: boolean
}

export const GROUP_IDS_IN_ORDER: readonly GroupId[] = ['say', 'slash', 'mine']

export const isLanguage = (value: unknown): value is Language => value === 'zh' || value === 'en'

/** Every word the pane draws itself, in each language. Tip text comes from the content files. */
export const UI_TEXT = {
  zh: {
    paneTitle: '速查',
    commandDescription: '打开或关闭速查面板',
    argumentHint: '[关键词]',
    searchPlaceholder: '搜索：画图、定时',
    searchSubmit: '搜',
    results: '搜索结果',
    noResults: '没有找到，换个词试试',
    unsorted: '未整理',
    filled: '已填入',
    copied: '已复制',
    missing: '已不存在',
    openFailed: '速查面板打开失败',
    groups: { say: '直接说', slash: '斜杠命令', mine: '我的' },
    notices: {
      runtimeBroken: 'tips.json 无法读取，已改用面板自带的副本',
      localBroken: 'tips.local.json 不是有效的 JSON，已忽略',
      skipped: (count: number) => `跳过 ${count} 条字段不全的条目`,
    },
  },
  en: {
    paneTitle: 'Tips',
    commandDescription: 'Open or close the tips pane',
    argumentHint: '[keyword]',
    searchPlaceholder: 'Search: chart, schedule',
    searchSubmit: 'Go',
    results: 'Results',
    noResults: 'Nothing found. Try another word.',
    unsorted: 'Unsorted',
    filled: 'Filled',
    copied: 'Copied',
    missing: 'Gone',
    openFailed: 'Could not open the tips pane',
    groups: { say: 'Just say it', slash: 'Slash commands', mine: 'Mine' },
    notices: {
      runtimeBroken: "tips.json can't be read; using the copy bundled with the pane",
      localBroken: 'tips.local.json is not valid JSON; ignored',
      skipped: (count: number) => `Skipped ${count} ${count === 1 ? 'entry' : 'entries'} with missing fields`,
    },
  },
} as const

/** The labels of the language switch, each in its own language. */
export const LANGUAGE_LABELS: Record<Language, string> = { zh: '中文', en: 'EN' }

export function noticeText(notice: Notice, language: Language): string {
  const text = UI_TEXT[language].notices
  switch (notice.kind) {
    case 'runtime-broken':
      return text.runtimeBroken
    case 'local-broken':
      return text.localBroken
    case 'skipped':
      return text.skipped(notice.count)
  }
}

/**
 * The row as drawn in one language: English shows `en` text where the entry
 * has it and falls back to the Chinese otherwise. The other language's title
 * joins the keywords, so a search in either language still finds the row.
 */
export function localizeRow<T extends Tip>(row: T, language: Language): T {
  if (language === 'en') {
    const keywords = row.titleEn !== '' ? [...row.keywords, row.title] : row.keywords
    return {
      ...row,
      title: row.titleEn || row.title,
      detail: row.detailEn || row.detail,
      keywords,
    }
  }
  return row.titleEn !== '' ? { ...row, keywords: [...row.keywords, row.titleEn] } : row
}

const GROUP_IDS = new Set<string>(['say', 'slash', 'mine'])

const isText = (value: unknown): value is string =>
  typeof value === 'string' && value.trim() !== ''

const asRecord = (value: unknown): Record<string, unknown> | undefined =>
  typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined

/** Turns one raw entry into a Tip, or undefined when a required field is bad. */
export function toTip(raw: unknown): Tip | undefined {
  const entry = asRecord(raw)
  if (!entry) return undefined
  const { id, group, title, copy, detail, keywords, icon } = entry
  const source = asRecord(entry.source)
  const english = asRecord(entry.en)
  if (!isText(id) || !isText(title) || !isText(copy)) return undefined
  if (typeof group !== 'string' || !GROUP_IDS.has(group)) return undefined
  return {
    id,
    group: group as GroupId,
    title,
    copy,
    detail: isText(detail) ? detail : '',
    titleEn: isText(english?.title) ? english.title : '',
    detailEn: isText(english?.detail) ? english.detail : '',
    keywords: Array.isArray(keywords) ? keywords.filter(isText) : [],
    icon: isText(icon) ? icon : '',
    sourceKind: isText(source?.kind) ? source.kind : '',
    sourceName: isText(source?.name) ? source.name : '',
  }
}

/**
 * Parses a tips file's text. Never throws: a file that is not JSON comes back
 * with `isBroken`, and each entry that does not hold up counts as skipped.
 */
export function parseTipsFile(text: string | undefined): ParsedFile {
  const empty: ParsedFile = { tips: [], hiddenIds: [], skipped: 0, isBroken: false }
  if (text === undefined) return empty
  let data: unknown
  try {
    data = JSON.parse(text)
  } catch {
    return { ...empty, isBroken: true }
  }
  const list = asRecord(data)?.tips
  if (!Array.isArray(list)) return { ...empty, isBroken: true }

  const result: ParsedFile = { ...empty, tips: [], hiddenIds: [] }
  for (const raw of list) {
    const entry = asRecord(raw)
    if (entry?.hidden === true && isText(entry.id)) {
      result.hiddenIds.push(entry.id)
      continue
    }
    const tip = toTip(raw)
    if (tip) result.tips.push(tip)
    else result.skipped += 1
  }
  return result
}

/**
 * Public first, then local: a local tip with the same id replaces the public
 * one in place; a local `hidden: true` entry removes the public tip.
 */
export function mergeTips(publicTips: Tip[], localFile: ParsedFile): Tip[] {
  const hidden = new Set(localFile.hiddenIds)
  const localById = new Map(localFile.tips.map(tip => [tip.id, tip]))
  const merged: Tip[] = []
  const seen = new Set<string>()
  for (const tip of publicTips) {
    if (hidden.has(tip.id) || seen.has(tip.id)) continue
    seen.add(tip.id)
    merged.push(localById.get(tip.id) ?? tip)
  }
  for (const tip of localFile.tips) {
    if (seen.has(tip.id) || hidden.has(tip.id)) continue
    seen.add(tip.id)
    merged.push(tip)
  }
  return merged
}

/**
 * Case-insensitive substring search over title, copy and keywords. Ranked:
 * title prefix, title contains, keyword hit, copy hit; file order within a rank.
 */
export function searchRows<T extends Tip>(rows: readonly T[], query: string): T[] {
  const needle = query.trim().toLowerCase()
  if (needle === '') return [...rows]
  const ranked: { row: T; rank: number; index: number }[] = []
  rows.forEach((row, index) => {
    const title = row.title.toLowerCase()
    let rank = -1
    if (title.startsWith(needle)) rank = 0
    else if (title.includes(needle)) rank = 1
    else if (row.keywords.some(word => word.toLowerCase().includes(needle))) rank = 2
    else if (row.copy.toLowerCase().includes(needle)) rank = 3
    if (rank >= 0) ranked.push({ row, rank, index })
  })
  ranked.sort((a, b) => a.rank - b.rank || a.index - b.index)
  return ranked.map(item => item.row)
}

function unquote(value: string): string {
  const trimmed = value.trim()
  if (trimmed.length >= 2) {
    const first = trimmed[0]
    const last = trimmed[trimmed.length - 1]
    if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
      return trimmed.slice(1, -1)
    }
  }
  return trimmed
}

/**
 * Reads `name` and `description` from a SKILL.md frontmatter block. Handles
 * plain, quoted, folded (`>`) and literal (`|`) values; anything fancier is
 * read as plain text. Returns an empty object when there is no frontmatter.
 */
export function readFrontmatter(text: string): { name?: string; description?: string } {
  const lines = text.replace(/\r\n/g, '\n').split('\n')
  if (lines[0]?.trim() !== '---') return {}
  const end = lines.findIndex((line, index) => index > 0 && line.trim() === '---')
  if (end < 0) return {}
  const block = lines.slice(1, end)
  const found: Record<string, string> = {}
  for (let index = 0; index < block.length; index += 1) {
    const match = /^([A-Za-z_][\w-]*):\s*(.*)$/.exec(block[index] ?? '')
    if (!match) continue
    const key = match[1] ?? ''
    let value = match[2] ?? ''
    const continued: string[] = []
    while (index + 1 < block.length && /^(\s+|$)/.test(block[index + 1] ?? '')) {
      const next = block[index + 1] ?? ''
      if (next.trim() === '' && !/^[>|]/.test(value)) break
      continued.push(next.trim())
      index += 1
    }
    if (/^[>|][+-]?$/.test(value)) {
      const joiner = value.startsWith('|') ? '\n' : ' '
      value = continued.join(joiner).trim()
    } else if (continued.length > 0) {
      value = [value, ...continued].join(' ')
    }
    found[key] = unquote(value)
  }
  const result: { name?: string; description?: string } = {}
  if (isText(found.name)) result.name = found.name
  if (isText(found.description)) result.description = found.description
  return result
}

/**
 * Builds the drawn rows: merged tips marked missing when they point at a user
 * skill no longer on disk, plus one 未整理 row per skill no tip references.
 */
export function buildRows(
  tips: Tip[],
  skills: SkillInfo[] | undefined,
): { rows: Row[]; unsorted: Row[] } {
  const known = new Set<string>()
  for (const skill of skills ?? []) {
    known.add(skill.name)
    known.add(skill.dirName)
  }
  const rows: Row[] = tips.map(tip => ({
    ...tip,
    isMissing:
      skills !== undefined && tip.sourceKind === 'user-skill' && !known.has(tip.sourceName),
  }))
  const referenced = new Set(tips.map(tip => tip.sourceName).filter(name => name !== ''))
  const unsorted: Row[] = (skills ?? [])
    .filter(skill => !referenced.has(skill.name) && !referenced.has(skill.dirName))
    .map(skill => ({
      id: `unsorted-${skill.dirName}`,
      group: 'mine',
      title: skill.name,
      copy: `/${skill.name}`,
      detail: skill.description,
      titleEn: '',
      detailEn: '',
      keywords: [skill.dirName],
      icon: '',
      sourceKind: 'user-skill',
      sourceName: skill.name,
      isMissing: false,
    }))
  return { rows, unsorted }
}

