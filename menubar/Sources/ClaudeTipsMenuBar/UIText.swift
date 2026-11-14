import TipsCore

/// Every word the popover draws itself, in each language. Tip text comes from the content files.
struct UIText {
    let searchPlaceholder: String
    let noResults: String
    let emptyGroup: String
    let moreRows: (Int) -> String
    let pageDown: String
    let copied: String
    let missing: String
    let enterToCopy: String
    let details: String
    let back: String
    let copy: String
    let select: String
    let close: String
    let unsorted: String
    let quit: String
    let statusItem: String
    let switchLanguage: String

    static func of(_ language: TipLanguage) -> UIText {
        switch language {
        case .zh: return chinese
        case .en: return english
        }
    }

    static let chinese = UIText(
        searchPlaceholder: "搜一下：画图、定时、交接",
        noResults: "没有找到，换个词试试",
        emptyGroup: "这一组还没有条目",
        moreRows: { "还有 \($0) 条" },
        pageDown: "向下翻一页",
        copied: "已复制",
        missing: "已不存在",
        enterToCopy: "↵ 复制",
        details: "详情",
        back: "返回",
        copy: "复制",
        select: "选择",
        close: "关闭",
        unsorted: "未整理",
        quit: "退出 Claude Tips",
        statusItem: "速查",
        switchLanguage: "切换到英文（⌘L）"
    )

    static let english = UIText(
        searchPlaceholder: "Search: chart, schedule, handoff",
        noResults: "Nothing found. Try another word.",
        emptyGroup: "Nothing in this group yet",
        moreRows: { "\($0) more" },
        pageDown: "Page down",
        copied: "Copied",
        missing: "Gone",
        enterToCopy: "↵ Copy",
        details: "Details",
        back: "Back",
        copy: "Copy",
        select: "Select",
        close: "Close",
        unsorted: "Unsorted",
        quit: "Quit Claude Tips",
        statusItem: "Claude Tips",
        switchLanguage: "Switch to Chinese (⌘L)"
    )
}
