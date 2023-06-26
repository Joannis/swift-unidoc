import BSONDecoding
import BSONEncoding
import Signatures
import SymbolGraphs
import Testing

func TestGenerics(_ tests:TestGroup?)
{
    if  let tests:TestGroup = tests / "parameters"
    {
        let parameters:[GenericParameter] =
        [
            .init(name: "T", depth: 0),
            .init(name: "Element", depth: 0),
            .init(name: "Element", depth: 1),
            .init(name: "Element", depth: 12),
            .init(name: "🇺🇸", depth: 1776),
            .init(name: "🇺🇸", depth: .max),
        ]
        tests.do
        {
            let bson:BSON.List = .init(elements: parameters)
            let decoded:[GenericParameter] = try .init(bson: .init(bson))

            tests.expect(parameters ..? decoded)
        }
    }
    if  let tests:TestGroup = tests / "constraints"
    {
        for (name, expression):(String, GenericConstraint<Int32>.TypeExpression) in
        [
            ("nominal", .nominal(13)),
            ("complex", .complex("Dictionary<Int, String>.Index"))
        ]
        {
            guard let tests:TestGroup = tests / name
            else
            {
                continue
            }

            for (name, relation):(String, GenericConstraint<Int32>.TypeRelation) in
            [
                ("conformer", .conformer(of: expression)),
                ("subclass", .subclass(of: expression)),
                ("type", .type(expression)),
            ]
            {
                guard let tests:TestGroup = tests / name
                else
                {
                    continue
                }

                let constraint:GenericConstraint<Int32> = .init("T.RawValue",
                    is: relation)

                tests.do
                {
                    let bson:BSON.Document = .init(encoding: constraint)

                    let decoded:GenericConstraint<Int32> = try .init(bson: .init(bson))

                    tests.expect(constraint ==? decoded)
                }
            }
        }
    }
}
