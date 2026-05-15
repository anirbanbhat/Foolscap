import AppKit

final class LineNumberRulerView: NSRulerView {

    weak var textView: NSTextView?

    /// Character indices (start-of-line) where bookmarks are pinned.
    var bookmarkLineStarts: Set<Int> = [] {
        didSet { needsDisplay = true }
    }

    /// Lines edited since last save (orange stripe).
    var modifiedLineStarts: Set<Int> = [] {
        didSet { needsDisplay = true }
    }

    /// Lines modified before last save but now persisted (green stripe).
    var savedLineStarts: Set<Int> = [] {
        didSet { needsDisplay = true }
    }

    /// Lines containing a "marked" occurrence (purple stripe).
    var markedLineStarts: Set<Int> = [] {
        didSet { needsDisplay = true }
    }

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 48

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView)
    }

    required init(coder: NSCoder) { fatalError("not implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ note: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let textStorage = textView.textStorage else { return }

        // Background
        (NSColor.windowBackgroundColor.blended(withFraction: 0.08, of: .controlBackgroundColor) ?? .windowBackgroundColor).setFill()
        bounds.fill()

        // Right edge line
        NSColor.separatorColor.setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        line.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        line.lineWidth = 0.5
        line.stroke()

        let nsString = textStorage.string as NSString
        let visibleRect = textView.visibleRect
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let firstCharIndex = layoutManager.characterIndexForGlyph(at: visibleGlyphRange.location)

        var lineNumber = 1
        if firstCharIndex > 0 {
            let prefix = nsString.substring(with: NSRange(location: 0, length: firstCharIndex)) as NSString
            var i = 0
            while i < prefix.length {
                let r = prefix.range(of: "\n", options: [], range: NSRange(location: i, length: prefix.length - i))
                if r.location == NSNotFound { break }
                lineNumber += 1
                i = r.location + 1
            }
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let yInset = textView.textContainerInset.height
        let bookmarkColor = NSColor.systemBlue

        var glyphIndex = visibleGlyphRange.location
        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let lineRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

            let firstGlyphInLine = NSRange(location: lineGlyphRange.location, length: 0)
            var lineRect = layoutManager.boundingRect(forGlyphRange: firstGlyphInLine, in: textContainer)
            lineRect.origin.y += yInset - visibleRect.origin.y

            // Change-history stripe along the right edge of the gutter
            if modifiedLineStarts.contains(lineRange.location) {
                NSColor.systemOrange.setFill()
                NSRect(x: ruleThickness - 3, y: lineRect.origin.y, width: 2, height: max(2, lineRect.height)).fill()
            } else if savedLineStarts.contains(lineRange.location) {
                NSColor.systemGreen.setFill()
                NSRect(x: ruleThickness - 3, y: lineRect.origin.y, width: 2, height: max(2, lineRect.height)).fill()
            }
            // Mark-all stripe (separate column from change-history)
            if markedLineStarts.contains(lineRange.location) {
                NSColor.systemPurple.setFill()
                NSRect(x: ruleThickness - 7, y: lineRect.origin.y, width: 2, height: max(2, lineRect.height)).fill()
            }

            // Bookmark marker
            if bookmarkLineStarts.contains(lineRange.location) {
                let diameter: CGFloat = 8
                let markerRect = NSRect(
                    x: 4,
                    y: lineRect.origin.y + 4,
                    width: diameter,
                    height: diameter
                )
                bookmarkColor.setFill()
                NSBezierPath(ovalIn: markerRect).fill()
            }

            let label = "\(lineNumber)"
            let size = label.size(withAttributes: attrs)
            let drawRect = NSRect(
                x: ruleThickness - size.width - 6,
                y: lineRect.origin.y + 1,
                width: size.width,
                height: size.height
            )
            label.draw(in: drawRect, withAttributes: attrs)

            glyphIndex = NSMaxRange(lineGlyphRange)
            if lineGlyphRange.length == 0 { break }
            lineNumber += 1
        }

        let len = nsString.length
        if len > 0 {
            let lastChar = nsString.character(at: len - 1)
            if lastChar == 0x0A {
                let extraOrigin = layoutManager.extraLineFragmentRect.origin
                if extraOrigin.y != 0 || NSMaxRange(visibleGlyphRange) == layoutManager.numberOfGlyphs {
                    let y = extraOrigin.y + yInset - visibleRect.origin.y
                    let label = "\(lineNumber)"
                    let size = label.size(withAttributes: attrs)
                    let drawRect = NSRect(
                        x: ruleThickness - size.width - 6,
                        y: y + 1,
                        width: size.width,
                        height: size.height
                    )
                    label.draw(in: drawRect, withAttributes: attrs)
                }
            }
        } else {
            let label = "1"
            let size = label.size(withAttributes: attrs)
            let drawRect = NSRect(
                x: ruleThickness - size.width - 6,
                y: yInset + 1,
                width: size.width,
                height: size.height
            )
            label.draw(in: drawRect, withAttributes: attrs)
        }
    }
}
