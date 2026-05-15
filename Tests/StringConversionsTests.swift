import Foundation

func registerStringConversionsTests() {
    let suite = "StringConversions"

    test(suite, "camelCase from space-separated") {
        try assertEqual(StringConversions.camelCase("hello world"), "helloWorld")
    }
    test(suite, "camelCase from snake_case") {
        try assertEqual(StringConversions.camelCase("foo_bar_baz"), "fooBarBaz")
    }
    test(suite, "camelCase from kebab-case") {
        try assertEqual(StringConversions.camelCase("foo-bar-baz"), "fooBarBaz")
    }
    test(suite, "camelCase from PascalCase") {
        try assertEqual(StringConversions.camelCase("FooBarBaz"), "fooBarBaz")
    }
    test(suite, "camelCase from camelCase is unchanged") {
        try assertEqual(StringConversions.camelCase("alreadyCamelCase"), "alreadyCamelCase")
    }
    test(suite, "camelCase empty string") {
        try assertEqual(StringConversions.camelCase(""), "")
    }
    test(suite, "camelCase single word") {
        try assertEqual(StringConversions.camelCase("hello"), "hello")
    }
    test(suite, "camelCase preserves single uppercase") {
        try assertEqual(StringConversions.camelCase("X"), "x")
    }

    test(suite, "pascalCase from space") {
        try assertEqual(StringConversions.pascalCase("hello world"), "HelloWorld")
    }
    test(suite, "pascalCase from snake") {
        try assertEqual(StringConversions.pascalCase("foo_bar"), "FooBar")
    }
    test(suite, "pascalCase from camel") {
        try assertEqual(StringConversions.pascalCase("fooBar"), "FooBar")
    }
    test(suite, "pascalCase empty") {
        try assertEqual(StringConversions.pascalCase(""), "")
    }

    test(suite, "snakeCase from PascalCase") {
        try assertEqual(StringConversions.snakeCase("HelloWorld"), "hello_world")
    }
    test(suite, "snakeCase from camelCase") {
        try assertEqual(StringConversions.snakeCase("fooBarBaz"), "foo_bar_baz")
    }
    test(suite, "snakeCase from space") {
        try assertEqual(StringConversions.snakeCase("foo bar"), "foo_bar")
    }
    test(suite, "snakeCase from kebab") {
        try assertEqual(StringConversions.snakeCase("foo-bar"), "foo_bar")
    }
    test(suite, "snakeCase already snake stays") {
        try assertEqual(StringConversions.snakeCase("foo_bar"), "foo_bar")
    }

    test(suite, "kebabCase from PascalCase") {
        try assertEqual(StringConversions.kebabCase("HelloWorld"), "hello-world")
    }
    test(suite, "kebabCase from snake") {
        try assertEqual(StringConversions.kebabCase("foo_bar_baz"), "foo-bar-baz")
    }
    test(suite, "kebabCase from space") {
        try assertEqual(StringConversions.kebabCase("foo bar baz"), "foo-bar-baz")
    }

    // HTML encode
    test(suite, "htmlEncode &") {
        try assertEqual(StringConversions.htmlEncode("AT&T"), "AT&amp;T")
    }
    test(suite, "htmlEncode angle brackets") {
        try assertEqual(StringConversions.htmlEncode("<tag>"), "&lt;tag&gt;")
    }
    test(suite, "htmlEncode quote") {
        try assertEqual(StringConversions.htmlEncode("a \"b\""), "a &quot;b&quot;")
    }
    test(suite, "htmlEncode apostrophe") {
        try assertEqual(StringConversions.htmlEncode("don't"), "don&#39;t")
    }
    test(suite, "htmlEncode safe text unchanged") {
        try assertEqual(StringConversions.htmlEncode("hello world 123"), "hello world 123")
    }
    test(suite, "htmlEncode empty") {
        try assertEqual(StringConversions.htmlEncode(""), "")
    }
    test(suite, "htmlEncode preserves order") {
        // & must be encoded first so we don't double-encode the & in &lt;.
        try assertEqual(StringConversions.htmlEncode("<&>"), "&lt;&amp;&gt;")
    }
}
