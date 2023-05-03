import LexicalPaths
import JSONDecoding
import JSONEncoding

extension LexicalPath:JSONDecodable
{
    public
    init(json:JSON) throws
    {
        let json:JSON.Array = try .init(json: json)
        try json.shape.expect { $0 > 0 }

        let last:Int = json.index(before: json.endIndex)
        self.init(
            try json[..<last].map { try $0.decode() },
            try json[last].decode())
    }
}
