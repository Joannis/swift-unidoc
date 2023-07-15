import HTML
import MarkdownABI
import MarkdownRendering
import Testing

@main
enum Main:SyncTests
{
    private static
    func run(tests:TestGroup,
        expecting expected:String,
        from markdown:(inout MarkdownBinaryEncoder) -> ())
    {
        tests.do
        {
            let binary:MarkdownBinary = .init(bytecode: .init(with: markdown))
            let html:HTML = .init { $0 += binary }

            tests.expect(html.description ==? expected)
        }
    }

    static
    func run(tests:Tests)
    {
        if  let tests:TestGroup = tests / "pre" / "transparency"
        {
            self.run(tests: tests,
                expecting: "<pre><span>test</span></pre>")
            {
                $0[.pre]
                {
                    $0[.transparent] = "<span>test</span>"
                }
            }
        }
        if  let tests:TestGroup = tests / "pre" / "escaped-characters"
        {
            self.run(tests: tests,
                expecting: "<pre>&lt;span&gt;test&lt;/span&gt;</pre>")
            {
                $0[.pre] = "<span>test</span>"
            }
        }
        if  let tests:TestGroup = tests / "pre" / "newlines"
        {
            self.run(tests: tests,
                expecting: "<pre>    code\n    code</pre>")
            {
                $0[.pre] =
                """
                    code
                    code
                """
            }
        }
        if  let tests:TestGroup = tests / "pre" / "language"
        {
            self.run(tests: tests,
                expecting: "<pre class='language-swift'>code\ncode</pre>")
            {
                $0[.pre, { $0[.language] = "swift" }] = "code\ncode"
            }
        }
        if  let tests:TestGroup = tests / "pre" / "language" / "extra-css" / "before"
        {
            self.run(tests: tests,
                expecting: "<pre class='before language-swift'>code\ncode</pre>")
            {
                $0[.pre, { $0[.class] = "before" ; $0[.language] = "swift" }] = "code\ncode"
            }
        }
        if  let tests:TestGroup = tests / "pre" / "language" / "extra-css" / "after"
        {
            self.run(tests: tests,
                expecting: "<pre class='language-swift after'>code\ncode</pre>")
            {
                $0[.pre, { $0[.language] = "swift" ; $0[.class] = "after" }] = "code\ncode"
            }
        }
        if  let tests:TestGroup = tests / "pre" / "language" / "escaped-characters"
        {
            self.run(tests: tests,
                expecting: """
                <pre class='language-taylor&#39;s version'>\
                we r never ever ever getting back together\
                </pre>
                """)
            {
                $0[.pre, { $0[.language] = "taylor's version" }] =
                    "we r never ever ever getting back together"
            }
        }
        if  let tests:TestGroup = tests / "pre" / "highlighting"
        {
            self.run(tests: tests,
                expecting: """
                <pre class='language-swift'>\
                <span class='syntax-keyword'>let</span> \
                <span class='syntax-identifier'>x</span> = \
                <span class='syntax-literal'>5</span>\
                </pre>
                """)
            {
                $0[.pre, { $0[.language] = "swift" }]
                {
                    $0[.keyword] = "let"
                    $0 += " "
                    $0[.identifier] = "x"
                    $0 += " = "
                    $0[.literal] = "5"
                }
            }
        }
        if  let tests:TestGroup = tests / "pre" / "unicode"
        {
            self.run(tests: tests,
                expecting: """
                <pre class='language-swift'>let 🇺🇸 = "en-us"</pre>
                """)
            {
                $0[.pre, { $0[.language] = "swift" }] = "let 🇺🇸 = \"en-us\""
            }
        }
        if  let tests:TestGroup = tests / "multiple-classes"
        {
            self.run(tests: tests,
                expecting: "<p class='aaa bbb ccc'> </p>")
            {
                $0[.p, { $0[.class] = "aaa"; $0[.class] = "bbb"; $0[.class] = "ccc" }] = " "
            }
        }
        if  let tests:TestGroup = tests / "void-elements"
        {
            self.run(tests: tests,
                expecting: "<p><br><br><br></p>")
            {
                $0[.p]
                {
                    $0[.br]
                    $0[.br]
                    $0[.br]
                }
            }
        }
        if  let tests:TestGroup = tests / "attributes" / "nesting"
        {
            self.run(tests: tests,
                expecting: """
                <h1 class='a'>\
                <em class='b'>go to</em>\
                <a href='swift.org' class='c'>\
                <em class='d'>swift website</em>\
                </a>\
                <em class='e'>.</em>\
                </h1>
                """)
            {
                $0[.h1, { $0[.class] = "a" }]
                {
                    $0[.em, { $0[.class] = "b" }] = "go to"
                    $0[.a, { $0[.class] = "c" ; $0[.href] = "swift.org" }]
                    {
                        $0[.em, { $0[.class] = "d" }] = "swift website"
                    }
                    $0[.em, { $0[.class] = "e" }] = "."
                }
            }
        }
        if  let tests:TestGroup = tests / "attributes" / "checkbox"
        {
            self.run(tests: tests,
                expecting: "<input type='checkbox' checked disabled>")
            {
                $0[.input]
                {
                    $0[.checkbox] = true
                    $0[.checked] = true
                    $0[.disabled] = true
                }
            }
        }
        if  let tests:TestGroup = tests / "attributes" / "align"
        {
            for pseudo:MarkdownBytecode.Attribute in [.center, .left, .right]
            {
                if  let tests:TestGroup = tests / "\(pseudo)"
                {
                    self.run(tests: tests,
                        expecting: "<td align='\(pseudo)'> </td>")
                    {
                        $0[.td, { $0[pseudo] = true }] = " "
                    }
                }
            }
        }
        if  let tests:TestGroup = tests / "sections"
        {
            self.run(tests: tests,
                expecting: """
                <section class='custom parameters'>\
                <h2>Parameters</h2>\
                <dl>\
                <dt>name</dt><dd>documentation</dd>\
                </dl>\
                </section>
                """)
            {
                $0[.parameters, { $0[.class] = "custom" }]
                {
                    $0[.dl]
                    {
                        $0[.dt] = "name"
                        $0[.dd] = "documentation"
                    }
                }
            }
        }
        if  let tests:TestGroup = tests / "signage"
        {
            self.run(tests: tests,
                expecting: """
                <aside class='warning'>\
                <h3>Warning</h3>\
                <p>don’t use this!</p>\
                </aside>
                """)
            {
                $0[.warning]
                {
                    $0[.p] = "don’t use this!"
                }
            }
        }
        if  let tests:TestGroup = tests / "references"
        {
            self.run(tests: tests,
                expecting: """
                <p><code>&lt;reference = 12345&gt;</code></p>
                """)
            {
                $0[.p] { $0 &= 12345 }
            }

            for (name, reference):(String, UInt32) in
            [
                ("uint8",    255),
                ("uint16", 65535),
                ("uint32",  .max),
            ]
            {
                guard let tests:TestGroup = tests / name
                else
                {
                    continue
                }
                self.run(tests: tests,
                    expecting: """
                    <p><code>&lt;reference = \(reference)&gt;</code></p>
                    """)
                {
                    $0[.p] { $0 &= reference }
                }
            }
        }
        if  let tests:TestGroup = tests / "references" / "success"
        {
            struct Renderable:HyperTextRenderableMarkdown
            {
                let bytecode:MarkdownBytecode = .init
                {
                    $0[.p]
                    {
                        $0 += "before"
                        $0 &= 0xAA_BB_CC_DD
                        $0 += "after"
                    }
                }

                func load(_ reference:UInt32, into html:inout HTML.ContentEncoder)
                {
                    html[.a, { $0[.href] = "swiftinit.org" }] = String.init(reference,
                        radix: 16)
                }
            }

            let renderable:Renderable = .init()
            let html:HTML = .init { $0 += renderable }

            tests.expect(html.description ==?
                "<p>before<a href='swiftinit.org'>aabbccdd</a>after</p>")
        }
        if  let tests:TestGroup = tests / "reference-attributes"
        {
            struct Renderable:HyperTextRenderableMarkdown
            {
                let bytecode:MarkdownBytecode

                init(reference:UInt32)
                {
                    self.bytecode = .init
                    {
                        $0[.pre]
                        {
                            $0[.code]
                            {
                                $0[.keyword] = "let"
                                $0 += " "
                                $0[.identifier] = "x"
                                $0 += ":"
                                $0[.type, { $0[.href] = reference }] = "Int"
                            }
                        }
                    }
                }

                func load(_ reference:UInt32, for _:MarkdownBytecode.Attribute) -> String?
                {
                    reference & 1 == 0 ? nil : "swiftinit.org"
                }
            }

            for (name, reference):(String, UInt32) in
            [
                ("uint8",    255),
                ("uint16", 65535),
                ("uint32",  .max),
            ]
            {
                guard let tests:TestGroup = tests / name
                else
                {
                    continue
                }

                let renderable:Renderable = .init(reference: reference)
                let html:HTML = .init { $0 += renderable }

                tests.expect(html.description ==? """
                    <pre><code>\
                    <span class='syntax-keyword'>let</span> \
                    <span class='syntax-identifier'>x</span>:\
                    <a href='swiftinit.org' class='syntax-type'>Int</a>\
                    </code></pre>
                    """)
            }

            if  let tests:TestGroup = tests / "failure"
            {
                let renderable:Renderable = .init(reference: 2)
                let html:HTML = .init { $0 += renderable }

                tests.expect(html.description ==? """
                    <pre><code>\
                    <span class='syntax-keyword'>let</span> \
                    <span class='syntax-identifier'>x</span>:\
                    <span class='syntax-type'>Int</span>\
                    </code></pre>
                    """)
            }
        }
    }
}
