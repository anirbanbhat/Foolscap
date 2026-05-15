import Foundation

func registerMarkdownRendererTests() {
    let suite = "MarkdownRenderer"

    // escapeHTML
    test(suite, "escapeHTML basic") {
        try assertEqual(MarkdownRenderer.escapeHTML("a & b"), "a &amp; b")
    }
    test(suite, "escapeHTML angle brackets") {
        try assertEqual(MarkdownRenderer.escapeHTML("<a>"), "&lt;a&gt;")
    }
    test(suite, "escapeHTML preserves quotes") {
        try assertEqual(MarkdownRenderer.escapeHTML("a \"b\""), "a &quot;b&quot;")
    }

    // inlineHTML
    test(suite, "inlineHTML code span") {
        try assertContains(MarkdownRenderer.inlineHTML("a `b` c"), "<code>b</code>")
    }
    test(suite, "inlineHTML bold") {
        try assertContains(MarkdownRenderer.inlineHTML("a **b** c"), "<strong>b</strong>")
    }
    test(suite, "inlineHTML italic") {
        try assertContains(MarkdownRenderer.inlineHTML("a *b* c"), "<em>b</em>")
    }
    test(suite, "inlineHTML link") {
        let h = MarkdownRenderer.inlineHTML("[hello](http://x)")
        try assertContains(h, "<a href=\"http://x\">hello</a>")
    }
    test(suite, "inlineHTML preserves order: bold doesn't become two italics") {
        // **foo** should be <strong>foo</strong>, not <em><em>foo</em></em>
        let h = MarkdownRenderer.inlineHTML("**foo**")
        try assertContains(h, "<strong>foo</strong>")
        try assertNotContains(h, "<em>")
    }

    // isSeparatorRow
    test(suite, "isSeparatorRow with all dashes") {
        try assertTrue(MarkdownRenderer.isSeparatorRow(["---", "---", "---"]))
    }
    test(suite, "isSeparatorRow with alignment colons") {
        try assertTrue(MarkdownRenderer.isSeparatorRow([":---", "---:", ":---:"]))
    }
    test(suite, "isSeparatorRow with empty cell is not a separator") {
        try assertFalse(MarkdownRenderer.isSeparatorRow(["---", "", "---"]))
    }
    test(suite, "isSeparatorRow with non-dash content is not a separator") {
        try assertFalse(MarkdownRenderer.isSeparatorRow(["---", "foo", "---"]))
    }

    // toHTML - block elements
    test(suite, "toHTML H1") {
        try assertContains(MarkdownRenderer.toHTML("# Hello"), "<h1>Hello</h1>")
    }
    test(suite, "toHTML H2") {
        try assertContains(MarkdownRenderer.toHTML("## Foo"), "<h2>Foo</h2>")
    }
    test(suite, "toHTML H3") {
        try assertContains(MarkdownRenderer.toHTML("### Bar"), "<h3>Bar</h3>")
    }
    test(suite, "toHTML heading max level 6") {
        try assertContains(MarkdownRenderer.toHTML("####### too many"), "<h6>too many</h6>")
    }
    test(suite, "toHTML paragraph wraps text") {
        let h = MarkdownRenderer.toHTML("Hello world.")
        try assertContains(h, "<p>Hello world.</p>")
    }
    test(suite, "toHTML two paragraphs separated by blank line") {
        let md = "First paragraph.\n\nSecond paragraph."
        let h = MarkdownRenderer.toHTML(md)
        try assertContains(h, "<p>First paragraph.</p>")
        try assertContains(h, "<p>Second paragraph.</p>")
    }
    test(suite, "toHTML unordered list") {
        let h = MarkdownRenderer.toHTML("- one\n- two\n- three")
        try assertContains(h, "<ul>")
        try assertContains(h, "<li>one</li>")
        try assertContains(h, "<li>two</li>")
        try assertContains(h, "<li>three</li>")
        try assertContains(h, "</ul>")
    }
    test(suite, "toHTML ordered list") {
        let h = MarkdownRenderer.toHTML("1. one\n2. two")
        try assertContains(h, "<ol>")
        try assertContains(h, "<li>one</li>")
        try assertContains(h, "<li>two</li>")
        try assertContains(h, "</ol>")
    }
    test(suite, "toHTML list closes before paragraph") {
        let h = MarkdownRenderer.toHTML("- item\n\nParagraph after.")
        try assertContains(h, "</ul>")
        try assertContains(h, "<p>Paragraph after.</p>")
    }
    test(suite, "toHTML blockquote") {
        let h = MarkdownRenderer.toHTML("> quoted")
        try assertContains(h, "<blockquote>")
        try assertContains(h, "quoted")
    }
    test(suite, "toHTML code fence") {
        let h = MarkdownRenderer.toHTML("```\nlet x = 1\n```")
        try assertContains(h, "<pre><code>")
        try assertContains(h, "let x = 1")
        try assertContains(h, "</code></pre>")
    }
    test(suite, "toHTML code fence escapes HTML") {
        let h = MarkdownRenderer.toHTML("```\n<not a tag>\n```")
        try assertContains(h, "&lt;not a tag&gt;")
    }
    test(suite, "toHTML horizontal rule") {
        try assertContains(MarkdownRenderer.toHTML("---"), "<hr/>")
    }
    test(suite, "toHTML table") {
        let md = "| Col1 | Col2 |\n|---|---|\n| a | b |\n| c | d |"
        let h = MarkdownRenderer.toHTML(md)
        try assertContains(h, "<table>")
        try assertContains(h, "<th>Col1</th>")
        try assertContains(h, "<th>Col2</th>")
        try assertContains(h, "<td>a</td>")
        try assertContains(h, "<td>d</td>")
        try assertContains(h, "</table>")
    }
    test(suite, "toHTML table separator row is skipped") {
        let md = "| H |\n|---|\n| v |"
        let h = MarkdownRenderer.toHTML(md)
        // Separator row should not appear as a <td>---</td>
        try assertNotContains(h, "<td>---</td>")
    }
    test(suite, "toHTML inline markup inside paragraph") {
        let h = MarkdownRenderer.toHTML("Bold **text** and *italic*.")
        try assertContains(h, "<strong>text</strong>")
        try assertContains(h, "<em>italic</em>")
    }
    test(suite, "toHTML inline code") {
        let h = MarkdownRenderer.toHTML("Run `swift build`.")
        try assertContains(h, "<code>swift build</code>")
    }
    test(suite, "toHTML inline angle brackets escape but stay text") {
        let h = MarkdownRenderer.toHTML("Use <foo> at your peril.")
        try assertContains(h, "&lt;foo&gt;")
    }
    test(suite, "toHTML preserves leading-hash heading without bold") {
        let h = MarkdownRenderer.toHTML("# Plain heading")
        try assertContains(h, "<h1>Plain heading</h1>")
        try assertNotContains(h, "<strong>")
    }
    test(suite, "toHTML empty input is empty output") {
        try assertEqual(MarkdownRenderer.toHTML(""), "")
    }
    test(suite, "toHTML multi-line paragraph joins lines") {
        let md = "Line one\nLine two\nLine three"
        let h = MarkdownRenderer.toHTML(md)
        try assertContains(h, "<p>Line one Line two Line three</p>")
    }
}
