export type GroupId = 'say' | 'slash' | 'mine'

/** One tip as read from a content file. */
export type Tip = {
  id: string
  group: GroupId
  title: string
  copy: string
  detail: string
  keywords: string[]
  icon: string
  sourceKind: string
  sourceName: string
}

/** A tip as the pane draws it, after merging and the skill scan. */
export type Row = Tip & { isMissing: boolean }

/** What the pane loaded the last time it opened. */
export type Library = {
  rows: Row[]
  unsorted: Row[]
  /** Chinese lines shown at the bottom of the pane when something was skipped. */
  notices: string[]
}

/** The short status a row shows right after a press. */
export type Feedback = { id: string; label: '已填入' | '已复制' }

declare module 'claude-code' {
  interface PluginState {
    'tips-pane': {
      library: Shaped<Library | null>
      query: string
      feedback: Shaped<Feedback | null>
      expanded: string | null
    }
  }
}
