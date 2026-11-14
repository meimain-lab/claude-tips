export type GroupId = 'say' | 'slash' | 'mine'

/** The pane's two views: Chinese explanations, or everything in English. */
export type Language = 'zh' | 'en'

/** One tip as read from a content file. */
export type Tip = {
  id: string
  group: GroupId
  title: string
  copy: string
  detail: string
  /** English title and detail from the entry's `en` object; '' when it has none. */
  titleEn: string
  detailEn: string
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
  /** What was skipped while loading, drawn at the bottom in the chosen language. */
  notices: Notice[]
}

export type Notice =
  | { kind: 'runtime-broken' }
  | { kind: 'local-broken' }
  | { kind: 'skipped'; count: number }

/** The short status a row shows right after a press. */
export type Feedback = { id: string; kind: 'filled' | 'copied' }

declare module 'claude-code' {
  interface PluginState {
    'tips-pane': {
      library: Shaped<Library | null>
      query: string
      feedback: Shaped<Feedback | null>
      expanded: string | null
      /** The chosen view for this session; null until read from the store. */
      language: Language | null
    }
  }
}
