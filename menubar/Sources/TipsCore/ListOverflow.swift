import Foundation

/// Where a fixed-pitch list's viewport sits over its rows, derived from the
/// real scroll offset. Drives the edge fades and the 还有 N 条 hint.
public struct ListOverflow: Equatable, Sendable {
    /// Rows hidden or cut off above the viewport.
    public let rowsAbove: Int
    /// Rows hidden or cut off below the viewport (the N in 还有 N 条).
    public let rowsBelow: Int
    public let isAtTop: Bool
    public let isAtBottom: Bool
    /// The first row that is not fully visible below; scrolling it to the top pages down.
    public let firstRowBelow: Int?

    /// Height of the list viewport. A list that fits shows all its rows; a longer
    /// one shows `visibleRows` rows plus half of the next, so the cut row itself
    /// says the list continues (and the 还有 N 条 hint sits over that cut row).
    public static func viewportHeight(rowCount: Int, rowHeight: Double, spacing: Double, visibleRows: Int) -> Double {
        let pitch = rowHeight + spacing
        if rowCount <= visibleRows { return Double(max(0, rowCount)) * pitch }
        return Double(visibleRows) * pitch + rowHeight / 2
    }

    /// - Parameters:
    ///   - rowCount: number of rows.
    ///   - rowHeight: height of one row.
    ///   - spacing: gap between rows.
    ///   - viewportHeight: visible height of the list.
    ///   - offset: how far the content is scrolled down (0 at the top).
    public init(rowCount: Int, rowHeight: Double, spacing: Double, viewportHeight: Double, offset: Double) {
        let tolerance = 0.5
        let pitch = rowHeight + spacing
        let contentHeight = rowCount > 0 ? Double(rowCount) * pitch - spacing : 0
        let maxOffset = max(0, contentHeight - viewportHeight)
        let top = min(max(0, offset), maxOffset)
        let bottom = top + viewportHeight

        var above = 0
        var below = 0
        var firstBelow: Int?
        for index in 0..<max(0, rowCount) {
            let rowTop = Double(index) * pitch
            let rowBottom = rowTop + rowHeight
            if rowTop < top - tolerance { above += 1 }
            if rowBottom > bottom + tolerance {
                below += 1
                if firstBelow == nil { firstBelow = index }
            }
        }
        rowsAbove = above
        rowsBelow = below
        isAtTop = top <= tolerance
        isAtBottom = top >= maxOffset - tolerance
        firstRowBelow = firstBelow
    }
}
