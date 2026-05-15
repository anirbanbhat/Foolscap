import AppKit

/// Lightweight minimap that draws each text line as a horizontal stroke (width
/// proportional to the line's character count). A viewport rectangle overlays
/// the section currently visible in the main editor. Cheaper than rendering
/// actual text at micro-font sizes.
final class MinimapView: NSView {

    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?

    private static let lineHeight: CGFloat = 2
    private static let maxLineWidth: CGFloat = 80

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        NotificationCenter.default.addObserver(self, selector: #selector(invalidate), name: NSText.didChangeNotification, object: textView)
        if let contentView = scrollView.contentView as NSClipView? {
            contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(invalidate), name: NSView.boundsDidChangeNotification, object: contentView)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func invalidate() { needsDisplay = true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 96, height: NSView.noIntrinsicMetric)
    }

    override func draw(_ rect: NSRect) {
        guard let textView = textView, let scrollView = scrollView else { return }
        let nsString = textView.string as NSString

        // Compute mapping from line index → minimap y.
        let lines = countLines(nsString)
        guard lines > 0 else { return }

        let totalContentHeight = CGFloat(lines) * MinimapView.lineHeight
        let availableHeight = bounds.height
        // Scale so the entire document fits if possible; otherwise show a top window.
        let scale = min(1.0, availableHeight / max(1, totalContentHeight))
        let drawHeight = totalContentHeight * scale
        let lineH = MinimapView.lineHeight * scale

        // Background already filled by layer.

        // Draw line strokes (one per text line).
        let strokeColor = NSColor.secondaryLabelColor.withAlphaComponent(0.55)
        strokeColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = max(0.5, lineH * 0.7)

        var lineIdx = 0
        var i = 0
        let length = nsString.length
        while i < length {
            let lineRange = nsString.lineRange(for: NSRange(location: i, length: 0))
            let content = nsString.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
            let chars = (content as NSString).length
            if chars > 0 {
                let width = min(CGFloat(chars), MinimapView.maxLineWidth)
                let y = drawHeight - CGFloat(lineIdx) * lineH - lineH / 2
                let x0: CGFloat = 6
                let x1 = x0 + width * (bounds.width - 12) / MinimapView.maxLineWidth
                path.move(to: NSPoint(x: x0, y: y))
                path.line(to: NSPoint(x: x1, y: y))
            }
            i = NSMaxRange(lineRange)
            lineIdx += 1
            if lineRange.length == 0 { break }
        }
        path.stroke()

        // Viewport rectangle.
        let visible = textView.visibleRect
        let totalEditorHeight = max(1, textView.bounds.height)
        let topRatio = visible.minY / totalEditorHeight
        let heightRatio = visible.height / totalEditorHeight
        let viewportY = drawHeight - (topRatio + heightRatio) * drawHeight
        let viewportHeight = heightRatio * drawHeight
        let viewportRect = NSRect(x: 0, y: viewportY, width: bounds.width, height: viewportHeight)

        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        viewportRect.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.45).setStroke()
        let frame = NSBezierPath(rect: viewportRect.insetBy(dx: 0.5, dy: 0.5))
        frame.lineWidth = 0.5
        frame.stroke()

        _ = scrollView   // silence weak-ref unused warning
    }

    override func mouseDown(with event: NSEvent) {
        scroll(to: event)
    }

    override func mouseDragged(with event: NSEvent) {
        scroll(to: event)
    }

    private func scroll(to event: NSEvent) {
        guard let textView = textView else { return }
        let pt = convert(event.locationInWindow, from: nil)
        // Same scale math as draw().
        let nsString = textView.string as NSString
        let lines = countLines(nsString)
        let totalContentHeight = CGFloat(lines) * MinimapView.lineHeight
        let scale = min(1.0, bounds.height / max(1, totalContentHeight))
        let drawHeight = totalContentHeight * scale
        // y=0 at bottom; line 0 at top of drawn area.
        let yFromTop = drawHeight - pt.y
        let ratio = max(0, min(1, yFromTop / max(1, drawHeight)))
        let target = ratio * max(1, textView.bounds.height) - textView.visibleRect.height / 2
        textView.scroll(NSPoint(x: 0, y: max(0, target)))
    }

    private func countLines(_ s: NSString) -> Int {
        var count = 1
        var i = 0
        let length = s.length
        while i < length {
            let r = s.range(of: "\n", options: [], range: NSRange(location: i, length: length - i))
            if r.location == NSNotFound { break }
            count += 1
            i = r.location + 1
        }
        return count
    }
}
