import AppKit

/// Left-aligned tab strip for workspace windows.
///
/// The content swap still lives in NSTabView; this view only provides the
/// visible, clickable tab row. It uses real NSButton subclasses for mouse
/// handling instead of relying on NSTabView's centered built-in tab layout.
final class WorkspaceTabBar: NSView {

    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onRequestMenu: ((Int) -> NSMenu?)?

    private struct Tab {
        var label: String
        var isPinned: Bool
        var isEdited: Bool
    }

    private var tabs: [Tab] = []
    private var buttons: [WorkspaceTabButton] = []
    private(set) var selectedIndex: Int = -1

    private let scrollView = NSScrollView()
    private let documentView = FlippedView()
    private let bottomLine = NSView()

    private let barHeight: CGFloat = 32
    private let tabHeight: CGFloat = 29
    private let horizontalInset: CGFloat = 4
    private let tabSpacing: CGFloat = 1
    private let minTabWidth: CGFloat = 92
    private let maxTabWidth: CGFloat = 260

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setUp() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.horizontalScrollElasticity = .allowed
        documentView.frame = NSRect(x: 0, y: 0, width: 1, height: barHeight)
        scrollView.documentView = documentView
        addSubview(scrollView)

        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.wantsLayer = true
        bottomLine.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(bottomLine)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: barHeight),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomLine.topAnchor),

            bottomLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomLine.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    func reload(tabs: [(label: String, isPinned: Bool, isEdited: Bool)], selected: Int) {
        self.tabs = tabs.map { Tab(label: $0.label, isPinned: $0.isPinned, isEdited: $0.isEdited) }

        for button in buttons {
            button.removeFromSuperview()
        }
        buttons.removeAll()

        for index in self.tabs.indices {
            let button = WorkspaceTabButton(index: index)
            button.onSelect = { [weak self] idx in self?.onSelect?(idx) }
            button.onClose = { [weak self] idx in self?.onClose?(idx) }
            button.onRequestMenu = { [weak self] idx in self?.onRequestMenu?(idx) }
            documentView.addSubview(button)
            buttons.append(button)
        }

        updateButtonContent()
        layoutButtons()
        select(at: selected)
    }

    func select(at index: Int) {
        selectedIndex = index
        for (i, button) in buttons.enumerated() {
            button.isTabSelected = (i == index)
        }
        scrollSelectionIntoView()
    }

    override func layout() {
        super.layout()
        layoutButtons()
        scrollSelectionIntoView()
    }

    private func updateButtonContent() {
        for (index, tab) in tabs.enumerated() {
            buttons[index].title = renderedTitle(for: tab)
        }
    }

    private func renderedTitle(for tab: Tab) -> String {
        let pin = tab.isPinned ? "● " : ""
        let dirty = tab.isEdited ? "• " : ""
        return pin + dirty + tab.label
    }

    private func layoutButtons() {
        guard bounds.width > 0 else { return }
        let height = max(bounds.height - 0.5, tabHeight)
        var x = horizontalInset

        for button in buttons {
            let desired = button.preferredWidth(minimum: minTabWidth, maximum: maxTabWidth)
            button.frame = NSRect(x: x, y: 0, width: desired, height: tabHeight)
            x += desired + tabSpacing
        }

        let totalWidth = max(x - tabSpacing + horizontalInset, bounds.width)
        documentView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: height)
    }

    private func scrollSelectionIntoView() {
        guard buttons.indices.contains(selectedIndex) else { return }
        let target = buttons[selectedIndex].frame.insetBy(dx: -horizontalInset, dy: 0)
        documentView.scrollToVisible(target)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

private final class WorkspaceTabButton: NSButton {

    let index: Int

    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onRequestMenu: ((Int) -> NSMenu?)?

    var isTabSelected = false {
        didSet { needsDisplay = true }
    }

    private var isHovered = false {
        didSet { needsDisplay = true }
    }

    private var trackingArea: NSTrackingArea?
    private let tabFont = NSFont.systemFont(ofSize: 12)
    private let closeImage = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .bold))

    private let titleLeading: CGFloat = 12
    private let titleToCloseSpacing: CGFloat = 6
    private let closeSize: CGFloat = 14
    private let closeTrailing: CGFloat = 8

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        wantsLayer = true
        focusRingType = .none
    }

    required init?(coder: NSCoder) { fatalError() }

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func preferredWidth(minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        let titleWidth = ceil((title as NSString).size(withAttributes: [.font: tabFont]).width)
        let desired = titleLeading + titleWidth + titleToCloseSpacing + closeSize + closeTrailing
        return min(max(desired, minimum), maximum)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control), popUpContextMenu(with: event) {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        if closeRect.contains(point), showsCloseButton {
            onClose?(index)
        } else {
            onSelect?(index)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if !popUpContextMenu(with: event) {
            super.rightMouseDown(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        onRequestMenu?(index)
    }

    @discardableResult
    private func popUpContextMenu(with event: NSEvent) -> Bool {
        guard let menu = onRequestMenu?(index) else { return false }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        return true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    private var showsCloseButton: Bool {
        isTabSelected || isHovered
    }

    private var closeRect: NSRect {
        NSRect(
            x: bounds.maxX - closeTrailing - closeSize,
            y: bounds.midY - closeSize / 2,
            width: closeSize,
            height: closeSize
        )
    }

    private var titleRect: NSRect {
        let close = closeRect
        return NSRect(
            x: bounds.minX + titleLeading,
            y: bounds.midY - 9,
            width: max(0, close.minX - titleToCloseSpacing - (bounds.minX + titleLeading)),
            height: 18
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let tabPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 2), xRadius: 5, yRadius: 5)
        if isTabSelected {
            NSColor.controlAccentColor.withAlphaComponent(0.32).setFill()
            tabPath.fill()
        } else if isHovered {
            NSColor.controlColor.withAlphaComponent(0.5).setFill()
            tabPath.fill()
        }

        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingMiddle
        let color = isTabSelected ? NSColor.labelColor : NSColor.secondaryLabelColor
        let attributed = NSAttributedString(
            string: title,
            attributes: [
                .font: tabFont,
                .foregroundColor: color,
                .paragraphStyle: style,
            ]
        )
        attributed.draw(with: titleRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])

        if showsCloseButton {
            if let closeImage = closeImage {
                closeImage.draw(in: closeRect)
            } else {
                "x".draw(in: closeRect, withAttributes: [
                    .font: NSFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ])
            }
        }
    }
}
