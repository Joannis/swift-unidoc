extension CodelinkV3.Path.Component
{
    @frozen public
    struct Arguments:Equatable, Hashable, Sendable
    {
        @usableFromInline internal
        var characters:String

        private
        init(characters:String = "")
        {
            self.characters = characters
        }
    }
}
extension CodelinkV3.Path.Component.Arguments:CustomStringConvertible
{
    @inlinable public
    var description:String
    {
        "(\(self.characters))"
    }
}
extension CodelinkV3.Path.Component.Arguments
{
    init?(parsing codepoints:inout Substring.UnicodeScalarView)
    {
        var remaining:Substring.UnicodeScalarView = codepoints

        if case "("? = remaining.popFirst()
        {
            self.init()
        }
        else
        {
            return nil
        }

        while let label:CodelinkV3.Identifier = .init(parsing: &remaining)
        {
            if  case ":"? = remaining.popFirst()
            {
                self.characters += label.characters
                self.characters.append(":")
            }
            else
            {
                return nil
            }
        }

        if case ")"? = remaining.popFirst()
        {
            codepoints = remaining
        }
        else
        {
            return nil
        }

        //  normalize
        if self.characters.isEmpty
        {
            return nil
        }
    }
}
