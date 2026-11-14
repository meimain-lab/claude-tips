// Icons for the pane. Content files name SF Symbols, which cannot ship with
// the repo, so each name maps to a small stroke drawing of our own on a
// 24 x 24 grid. Unknown names fall back to the group's icon.
import type { GroupId } from '../types'

export type IconGroup = GroupId | 'unsorted'

/** Stroke paths per SF Symbol name used by the content files (and a few common extras). */
export const ICON_PATHS: Record<string, string[]> = {
  'chart.bar': ['M4 20h16', 'M7 16v-4', 'M12 16V7', 'M17 16V9'],
  'arrow.triangle.2.circlepath': [
    'M19.5 10A8 8 0 0 0 5 7.5',
    'M4 4v4h4',
    'M4.5 14A8 8 0 0 0 19 16.5',
    'M20 20v-4h-4',
  ],
  play: ['M8 5l11 7-11 7z'],
  link: [
    'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1',
    'M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
  ],
  puzzlepiece: ['M4 8h4a2.5 2.5 0 1 1 4 0h4v4a2.5 2.5 0 1 1 0 4v4H4z'],
  ladybug: [
    'M12 8a4 4 0 0 1 4 4v3a4 4 0 0 1-8 0v-3a4 4 0 0 1 4-4z',
    'M10 8a2 2 0 0 1 4 0',
    'M12 12v7',
    'M4 13h4',
    'M16 13h4',
    'M5 8l3 2',
    'M19 8l-3 2',
    'M5 19l3-2',
    'M19 19l-3-2',
  ],
  'wand.and.stars': [
    'M4 20L15 9',
    'M13 7l4 4',
    'M18 3v3',
    'M16.5 4.5h3',
    'M8 3v2',
    'M7 4h2',
    'M20 13v2',
    'M19 14h2',
  ],
  'checkmark.shield': ['M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z', 'M9 12l2 2 4-4'],
  'lock.open': ['M6 11h12v9H6z', 'M9 11V8a3 3 0 0 1 5.8-1'],
  repeat: ['M4 11V9a3 3 0 0 1 3-3h12', 'M16 3l3 3-3 3', 'M20 13v2a3 3 0 0 1-3 3H5', 'M8 21l-3-3 3-3'],
  'calendar.badge.clock': [
    'M4 6h16v14H4z',
    'M4 10h16',
    'M8 3v4',
    'M16 3v4',
    'M8 14h2',
    'M12 14h2',
    'M8 17h2',
  ],
  'doc.text': ['M6 3h8l4 4v14H6z', 'M14 3v4h4', 'M9 12h6', 'M9 16h6'],
  'arrow.down.right.and.arrow.up.left': ['M4 14h6v6', 'M10 14l-6 6', 'M20 10h-6V4', 'M14 10l6-6'],
  star: ['M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z'],
  'note.text': ['M5 4h14v16H5z', 'M8 9h8', 'M8 13h8', 'M8 17h5'],
  'arrow.triangle.branch': ['M6 21V4', 'M3 7l3-3 3 3', 'M6 14c0-4 4-7 8-7h4', 'M15 4l3 3-3 3'],
  tag: ['M3 12V4h8l10 10-8 8z', 'M7.5 7.5h.01'],
  paperplane: ['M21 3L10 14', 'M21 3l-7 18-4-7-7-4z'],
  // Group icons, also used as fallbacks.
  'bubble.left': ['M4 5h16v11H9l-5 4z'],
  terminal: ['M4 7l5 5-5 5', 'M12 18h8'],
  tray: ['M3 13l3-8h12l3 8v6H3z', 'M3 13h5l1 2h6l1-2h5'],
}

export const GROUP_ICONS: Record<IconGroup, string> = {
  say: 'bubble.left',
  slash: 'terminal',
  mine: 'star',
  unsorted: 'tray',
}

/** The icon name to draw: the tip's own when the table has it, else its group's. */
export function iconFor(icon: string, group: IconGroup): string {
  return icon in ICON_PATHS ? icon : GROUP_ICONS[group]
}

/** Neutral grey that reads on both the light and the dark theme (the host does not say which). */
const NEUTRAL_STROKE = '#8E8E93'
const NEUTRAL_FILL = 'rgba(142,142,147,0.18)'
const ACTIVE_STROKE = '#FFFFFF'
const ACTIVE_FILL = 'rgba(255,255,255,0.22)'

const strokes = (name: string, stroke: string, width: number) =>
  `<g fill="none" stroke="${stroke}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round">` +
  (ICON_PATHS[name] ?? []).map(d => `<path d="${d}"/>`).join('') +
  '</g>'

/** A row's 32 px icon block: rounded tile and glyph in one image, so neither can cover or squeeze the other. */
export function tileSvg(name: string, isActive: boolean): string {
  const fill = isActive ? ACTIVE_FILL : NEUTRAL_FILL
  const stroke = isActive ? ACTIVE_STROKE : NEUTRAL_STROKE
  return (
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' +
    `<rect width="32" height="32" rx="8" fill="${fill}"/>` +
    `<g transform="translate(6 6) scale(0.8333)">${strokes(name, stroke, 2)}</g>` +
    '</svg>'
  )
}

/** A section header's bare 16 px icon. */
export function glyphSvg(name: string): string {
  return (
    '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24">' +
    strokes(name, NEUTRAL_STROKE, 2) +
    '</svg>'
  )
}

/** One character per group for the terminal, which has no Svg. */
export const GROUP_GLYPHS: Record<IconGroup, string> = {
  say: '“',
  slash: '/',
  mine: '☆',
  unsorted: '·',
}

/** The second line of an 未整理 row: the description's first sentence on one line. */
export function firstSentence(text: string): string {
  const flat = text.replace(/\s+/g, ' ').trim()
  const match = flat.match(/^.*?(?:[。！？]|[.!?](?=\s|$))/)
  return (match ? match[0] : flat).trim()
}
