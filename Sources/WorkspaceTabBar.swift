import AppKit

/// Custom horizontal tab strip used by WorkspaceWindowController instead of
/// NSTabView's built-in tab control.
///
/// Layout: a plain NSStackView pinned to the bar's edges. Buttons are added
/// with `.leading` gravity so they pack left-to-right. No NSScrollView —
/// when the buttons overflow they're clipped at the trailing edge. We can
/// add an overflow chevron later; the priority for now is that clicks land
/// where the user expects them.
final class WorkspaceTabBar: NSView {

    weak var workspace: WorkspaceWindowController?

    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onRequestMenu: ((Int) -> NSMenu?)?

    private(set) var selectedIndex: Int = -1
    private var buttons: [TabButton] = []

    private let stack = NSStackView()
    private let bottomLine = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setUp() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .gravityAreas
        stack.spacing = 1
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        addSubview(stack)

        bottomLine.translatesAutoresizingMaskIntoConstraints = false
        bottomLine.wantsLayer = true
        bottomLine.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(bottomLine)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomLine.topAnchor),

            bottomLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomLine.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    /// Replace the entire set of buttons. Cheap enough at our scale.
    func reload(tabs: [(label: String, isPinned: Bool, isEdited: Bool)], selected: Int) {
        for b in buttons {
            stack.removeView(b)
        }
        buttons.removeAll()

        for (i, t) in tabs.enumerated() {
            let btn = TabButton(index: i)
            btn.update(label: t.label, isPinned: t.isPinned, isEdited: t.isEdited)
            btn.onClick = { [weak self] idx in self?.onSelect?(idx) }
            btn.onClose = { [weak self] idx in self?.onClose?(idx) }
            btn.onRequestMenu = { [weak self] idx -> NSMenu? in self?.onRequestMenu?(idx) }
            // Leading gravity — buttons pack against the leading edge.
            stack.addView(btn, in: .leading)
            buttons.append(btn)
        }
        select(at: selected)
    }

    func select(at index: Int) {
        selectedIndex = index
        for (i, b) in buttons.enumerated() { b.isSelected = (i == index) }
    }

    func updateButton(at index: Int, label: String, isPinned: Bool, isEdited: Bool) {
        guard index >= 0 && index < buttons.count else { return }
        buttons[index].update(label: label, isPinned: isPinned, isEdited: isEdited)
    }
}

/// Single tab button.
final class TabButton: NSView {

    var index: Int
    var isSelected: Bool = false {
        didSet {
            needsDisplay = true
            label.textColor = isSelected ? NSColor.labelColor : NSColor.secondaryLabelColor
            closeButton.isHidden = !(isSelected || isHovered)
        }
    }
    private var isHovered: Bool = false {
        didSet {
            needsDisplay = true
            closeButton.isHidden = !(isHovered || isSelected)
        }
    }

    private let label = NSTextField(labelWithString: "")
    private let closeButton = NSButton(title: "", target: nil, action: nil)

    var onClick: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onRequestMenu: ((Int) -> NSMenu?)?

    private var trackingArea: NSTrackingArea?

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        label.cell?.usesSingleLineMode = true
        // Crucially: stop the label from eating mouseDown.
        label.refusesFirstResponder = true
        addSubview(label)

        let xImage = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .bold))
        closeButton.image = xImage
        closeButton.imagePosition = .imageOnly
        closeButton.bezelStyle = .smallSquare
        closeButton.isBordered = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.target = self
        closeButton.action = #selector(closeClicked(_:))
        closeButton.isHidden = true
        closeButton.contentTintColor = NSColor.secondaryLabelColor
        closeButton.refusesFirstResponder = true
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 28),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            widthAnchor.constraint(lessThanOrEqualToConstant: 220),

            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeButton.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 6),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 14),
            closeButton.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(label text: String, isPinned: Bool, isEdited: Bool) {
        var rendered = ""
        if isPinned { rendered += "● " }
        if isEdited { rendered += "• " }
        rendered += text
        label.stringValue = rendered
        label.textColor = isSelected ? NSColor.labelColor : NSColor.secondaryLabelColor
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    @objc private func closeClicked(_ sender: Any?) {
        onClose?(index)
    }

    /// Make sure clicks on the label or background fall through to us.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        if !closeButton.isHidden && closeButton.frame.contains(local) {
            return closeButton
        }
        return self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?(index)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return onRequestMenu?(index)
    }

    override func rightMouseDown(with event: NSEvent) {
        if let m = onRequestMenu?(index) {
            NSMenu.popUpContextMenu(m, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 2), xRadius: 5, yRadius: 5)
        if isSelected {
            NSColor.controlAccentColor.withAlphaComponent(0.28).setFill()
            path.fill()
        } else if isHovered {
            NSColor.controlColor.withAlphaComponent(0.5).setFill()
            path.fill()
        }
    }
}
