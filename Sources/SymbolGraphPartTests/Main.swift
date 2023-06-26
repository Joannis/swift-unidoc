import ModuleGraphs
import Signatures
import SymbolGraphParts
import Symbols
import System
import Testing
import Unidoc

@main
enum Main:SyncTests
{
    static
    func run(tests:Tests)
    {
        if  let tests:TestGroup = tests / "phyla",
            let part:SymbolGraphPart = tests.load(
                part: "TestModules/Symbolgraphs/Phyla.symbols.json")
        {
            for (symbol, phylum):([String], Unidoc.Decl) in
            [
                (["Actor"],                         .actor),
                (["Class"],                         .class),
                (["Enum"],                          .enum),
                (["Enum", "case"],                  .case),
                (["Protocol"],                      .protocol),
                (["Protocol", "AssociatedType"],    .associatedtype),
                (["Struct"],                        .struct),
                (["Typealias"],                     .typealias),
                (["Var"],                           .var(nil)),
            ]
            {
                if  let name:String = symbol.last?.lowercased(),
                    let tests:TestGroup = tests / name,
                    let symbol:SymbolDescription = tests.expect(symbol: symbol, in: part)
                {
                    tests.expect(symbol.phylum ==? .decl(phylum))
                }
            }
            for (symbol, phylum, name):([String], Unidoc.Decl, String) in
            [
                (["Func"],                      .func(nil),             "global-func"),
                (["Struct", "instanceMethod"],  .func(.instance),       "instance-func"),
                (["Struct", "staticMethod"],    .func(.static),         "static-func"),

                (["Struct", "instanceProperty"],.var(.instance),        "instance-var"),
                (["Struct", "staticProperty"],  .var(.static),          "static-var"),

                (["Struct", "subscript"],       .subscript(.instance),  "instance-subscript"),
                (["Struct", "subscript(_:)"],   .subscript(.static),    "static-subscript"),

                (["Class", "classMethod"],      .func(.class),          "class-func"),
                (["Class", "classProperty"],    .var(.class),           "class-var"),
                (["Class", "init"],             .initializer,           "class-init"),
                (["Actor", "init"],             .initializer,           "actor-init"),

                (["?/(_:)"],                    .operator,              "operator-prefix"),
                (["<-(_:_:)"],                  .operator,              "operator-infix"),
                (["/?(_:)"],                    .operator,              "operator-suffix"),

                (["Struct", "?/(_:)"],          .operator,              "type-operator-prefix"),
                (["Struct", "<-(_:_:)"],        .operator,              "type-operator-infix"),
                (["Struct", "/?(_:)"],          .operator,              "type-operator-suffix"),
            ]
            {
                if  let tests:TestGroup = tests / name,
                    let symbol:SymbolDescription = tests.expect(symbol: symbol, in: part)
                {
                    tests.expect(symbol.phylum ==? .decl(phylum))
                }
            }

            if  let tests:TestGroup = tests / "deinit"
            {
                tests.expect(nil: part.symbols.first { $0.phylum == .decl(.deinitializer) })
            }
        }
        if  let tests:TestGroup = tests / "phyla" / "extension",
            let part:SymbolGraphPart = tests.load(
                part: "TestModules/Symbolgraphs/Phyla@Swift.symbols.json")
        {
            for (symbol, phylum):([String], Unidoc.Phylum) in
            [
                (["Int"], .block),
                (["Int", "AssociatedType"], .decl(.typealias)),
            ]
            {
                if  let symbol:SymbolDescription = tests.expect(symbol: symbol, in: part)
                {
                    tests.expect(symbol.phylum ==? phylum)
                }
            }
        }
        if  let tests:TestGroup = tests / "spi",
            let part:SymbolGraphPart = tests.load(
                part: "TestModules/Symbolgraphs/SPI.symbols.json")
        {
            for (symbol, interfaces):([String], SymbolDescription.Interfaces?) in
            [
                (["NoSPI"], nil),
                (["SPI"], .init()),
            ]
            {
                if  let symbol:SymbolDescription = tests.expect(symbol: symbol, in: part)
                {
                    tests.expect(symbol.interfaces ==? interfaces)
                }
            }
        }
        if  let tests:TestGroup = tests / "internal-documentation-inheritance",
            let part:SymbolGraphPart = tests.load(
                part: "TestModules/Symbolgraphs/DocumentationInheritance.symbols.json")
        {
            for (symbol, culture, comment):([String], ModuleIdentifier?, String?) in
            [
                (
                    ["Protocol", "everywhere"],
                    "DocumentationInheritance",
                    "This comment is from the root protocol."
                ),
                (
                    ["Protocol", "protocol"],
                    "DocumentationInheritance",
                    "This comment is from the root protocol."
                ),
                (
                    ["Protocol", "refinement"],
                    nil,
                    nil
                ),
                (
                    ["Protocol", "conformer"],
                    nil,
                    nil
                ),
                (
                    ["Protocol", "nowhere"],
                    nil,
                    nil
                ),

                (
                    ["Refinement", "everywhere"],
                    "DocumentationInheritance",
                    "This comment is from the refined protocol."
                ),
                (
                    ["Refinement", "protocol"],
                    nil,
                    nil
                ),
                (
                    ["Refinement", "refinement"],
                    "DocumentationInheritance",
                    "This comment is from the refined protocol."
                ),
                (
                    ["Refinement", "conformer"],
                    nil,
                    nil
                ),
                (
                    ["Refinement", "nowhere"],
                    nil,
                    nil
                ),

                (
                    ["OtherRefinement", "everywhere"],
                    "DocumentationInheritance",
                    "This is a default implementation provided by a refined protocol."
                ),
                (
                    ["OtherRefinement", "protocol"],
                    nil,
                    nil
                ),

                (
                    ["Conformer", "everywhere"],
                    "DocumentationInheritance",
                    "This comment is from the conforming type."
                ),
                //  This would inherit (from Protocol) if the part
                //  were generated without `-skip-inherited-docs`.
                (
                    ["Conformer", "protocol"],
                    nil,
                    nil
                ),
                //  This would inherit (from Refinement) if the part
                //  were generated without `-skip-inherited-docs`.
                (
                    ["Conformer", "refinement"],
                    nil,
                    nil
                ),
                (
                    ["Conformer", "conformer"],
                    "DocumentationInheritance",
                    "This comment is from the conforming type."
                ),
                (
                    ["Conformer", "nowhere"],
                    nil,
                    nil
                ),
            ]
            {
                if  let tests:TestGroup = tests / symbol.joined(separator: "-").lowercased(),
                    let symbol:SymbolDescription = tests.expect(symbol: symbol, in: part)
                {
                    tests.expect(symbol.doccomment?.culture ==? culture)
                    tests.expect(symbol.doccomment?.text ==? comment)
                }
            }

            if  let tests:TestGroup = tests / "origins"
            {
                /// Concrete type members always get an origin edge pointing back
                /// to whatever requirement they fulfill, regardless of whether:
                ///
                /// -   they already have documentation of their own, or
                /// -   they had no documentation, and inherited no documentation.
                ///
                /// In both cases, they will get an edge to their immediate origin.
                /// If concrete type members do inherit documentation, their origin
                /// edges point to the symbols they inherited documenation from,
                /// even if there were undocumented symbols in between. (The edges
                /// “skip” the undocumented symbols.)
                ///
                /// Default implementations only get an origin edge if they actually
                /// had no documentation of their own, and successfully inherited some.
                tests.expect(part.relationships.filter
                {
                    $0.origin != nil
                }
                    **?
                [
                    .defaultImplementation(.init(.init(
                        "s:24DocumentationInheritance15OtherRefinementPAAE8protocolytvp")!,
                        of: .init("s:24DocumentationInheritance8ProtocolP8protocolytvp")!,
                        origin: .init(.init(
                            "s:24DocumentationInheritance8ProtocolP8protocolytvp")!))),

                    .membership(.init(of: .scalar(.init(
                        "s:24DocumentationInheritance9ConformerV7nowhereytvp")!),
                        in: .scalar(.init("s:24DocumentationInheritance9ConformerV")!),
                        origin: .init(.init(
                            "s:24DocumentationInheritance10RefinementP7nowhereytvp")!))),

                    .membership(.init(of: .scalar(.init(
                        "s:24DocumentationInheritance9ConformerV10refinementytvp")!),
                        in: .scalar(.init("s:24DocumentationInheritance9ConformerV")!),
                        origin: .init(.init(
                            "s:24DocumentationInheritance10RefinementP10refinementytvp")!))),

                    .membership(.init(of: .scalar(.init(
                        "s:24DocumentationInheritance9ConformerV9conformerytvp")!),
                        in: .scalar(.init("s:24DocumentationInheritance9ConformerV")!),
                        origin: .init(.init(
                            "s:24DocumentationInheritance10RefinementP9conformerytvp")!))),

                    .membership(.init(of: .scalar(.init(
                        "s:24DocumentationInheritance9ConformerV10everywhereytvp")!),
                        in: .scalar(.init("s:24DocumentationInheritance9ConformerV")!),
                        origin: .init(.init(
                            "s:24DocumentationInheritance10RefinementP10everywhereytvp")!))),

                    .membership(.init(of: .scalar(.init(
                        "s:24DocumentationInheritance9ConformerV8protocolytvp")!),
                        in: .scalar(.init("s:24DocumentationInheritance9ConformerV")!),
                        origin: .init(.init(
                            "s:24DocumentationInheritance8ProtocolP8protocolytvp")!))),
                ])
            }
        }
        if  let tests:TestGroup = tests / "external-documentation-inheritance",
            let part:SymbolGraphPart = tests.load(part: """
                TestModules/Symbolgraphs/DocumentationInheritanceFromSwift.symbols.json
                """)
        {
            for (symbol, culture, comment):([String], ModuleIdentifier?, String?) in
            [
                (
                    ["Documented", "id"],
                    "DocumentationInheritanceFromSwift",
                    "A documented id property."
                ),
                (
                    ["Undocumented", "id"],
                    nil,
                    nil
                ),
            ]
            {
                if  let tests:TestGroup = tests / symbol[0].lowercased(),
                    let symbol:SymbolDescription = tests.expect(symbol: symbol, in: part)
                {
                    tests.expect(symbol.doccomment?.culture ==? culture)
                    tests.expect(symbol.doccomment?.text ==? comment)
                }
            }

            if  let tests:TestGroup = tests / "origins"
            {
                /// Concrete type members always get an origin edge pointing back
                /// to whatever requirement they fulfill, regardless of whether:
                ///
                /// -   they already have documentation of their own, or
                /// -   they had no documentation, and inherited no documentation.
                ///
                /// In both cases, they will get an edge to their immediate origin.
                /// If concrete type members do inherit documentation, their origin
                /// edges point to the symbols they inherited documenation from,
                /// even if there were undocumented symbols in between. (The edges
                /// “skip” the undocumented symbols.)
                ///
                /// Default implementations only get an origin edge if they actually
                /// had no documentation of their own, and successfully inherited some.
                tests.expect(part.relationships.filter
                {
                    if  case .membership(let membership) = $0,
                        case .scalar = membership.source,
                        case _? = membership.origin
                    {
                        return true
                    }
                    else
                    {
                        return false
                    }
                }
                    **?
                [
                    .membership(.init(of: .scalar(.init(
                        "s:33DocumentationInheritanceFromSwift12UndocumentedV2ids5NeverOSgvp")!),
                        in: .scalar(.init(
                        "s:33DocumentationInheritanceFromSwift12UndocumentedV")!),
                        origin: .init(.init("s:s12IdentifiableP2id2IDQzvp")!))),

                    .membership(.init(of: .scalar(.init(
                        "s:33DocumentationInheritanceFromSwift10DocumentedV2ids5NeverOSgvp")!),
                        in: .scalar(.init(
                        "s:33DocumentationInheritanceFromSwift10DocumentedV")!),
                        origin: .init(.init("s:s12IdentifiableP2id2IDQzvp")!))),
                ])
            }
        }

        if  let tests:TestGroup = tests / "internal-extension-constraints",
            let part:SymbolGraphPart = tests.load(part: """
                TestModules/Symbolgraphs/InternalExtensionsWithConstraints.symbols.json
                """)
        {
            for (symbol, conditions):([String], [GenericConstraint<Symbol.Decl>]) in
            [
                (
                    ["Struct", "internal(_:)"],
                    [
                        .init("T", is: .conformer(of: .nominal(.init("s:SQ")!))),
                        .init("T", is: .conformer(of: .nominal(.init("s:ST")!))),
                    ]
                ),
                (
                    ["Protocol", "internal(_:)"],
                    [
                        .init("Self.T", is: .conformer(of: .nominal(.init("s:SQ")!))),
                    ]
                ),
            ]
            {
                if  let symbol:SymbolDescription = tests.expect(symbol: symbol, in: part)
                {
                    tests.expect(symbol.extension.conditions ..? conditions)
                }
            }
        }
        if  let tests:TestGroup = tests / "external-extension-constraints",
            let part:SymbolGraphPart = tests.load(part: """
                TestModules/Symbolgraphs/\
                ExternalExtensionsWithConstraints@\
                ExtendableTypesWithConstraints.symbols.json
                """)
        {
            for (symbol, conditions):([String], [GenericConstraint<Symbol.Decl>]) in
            [
                (
                    ["Struct"],
                    [
                        .init("T", is: .conformer(of: .nominal(.init("s:SQ")!))),
                        .init("T", is: .conformer(of: .nominal(.init("s:ST")!))),
                    ]
                ),
                (
                    ["Struct", "external(_:)"],
                    [
                        .init("T", is: .conformer(of: .nominal(.init("s:SQ")!))),
                        .init("T", is: .conformer(of: .nominal(.init("s:ST")!))),
                    ]
                ),
                (
                    ["Protocol"],
                    [
                        .init("Self.T", is: .conformer(of: .nominal(.init("s:SQ")!))),
                    ]
                ),
                (
                    ["Protocol", "external(_:)"],
                    [
                        .init("Self.T", is: .conformer(of: .nominal(.init("s:SQ")!))),
                    ]
                ),
            ]
            {
                if  let symbol:SymbolDescription = tests.expect(symbol: symbol, in: part)
                {
                    tests.expect(symbol.extension.conditions ..? conditions)
                }
            }
        }
    }
}
