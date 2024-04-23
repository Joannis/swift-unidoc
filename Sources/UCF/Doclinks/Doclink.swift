import URI

@frozen public
struct Doclink:Equatable, Hashable, Sendable
{
    public
    let absolute:Bool
    public
    let path:[String]
    public
    let fragment:String?

    @inlinable public
    init(absolute:Bool, path:[String], fragment:String? = nil)
    {
        self.absolute = absolute
        self.path = path
        self.fragment = fragment
    }
}
extension Doclink
{
    @inlinable public
    var bundle:String?
    {
        self.absolute ? self.path.first : nil
    }
    /// Returns the string value of the doclink, without the `doc:` prefix, percent-encoding any
    /// special characters as needed.
    @inlinable public
    var text:String
    {
        var first:Bool = true
        var text:String = self.absolute ? "//" : ""
        for component:String in self.path
        {
            if  first
            {
                first = false
            }
            else
            {
                text.append("/")
            }

            text += "\(URI.Path.Component.push(component))"
        }
        if  let fragment:String = self.fragment
        {
            text += "\(URI.Fragment.init(decoded: fragment))"
        }

        return text
    }
}
extension Doclink:CustomStringConvertible
{
    @inlinable public
    var description:String { "doc:\(self.text)" }
}
extension Doclink:LosslessStringConvertible
{
    public
    init?(_ description:String)
    {
        if  let start:String.Index = description.index(description.startIndex,
                offsetBy: 4,
                limitedBy: description.endIndex),
            description[..<start] == "doc:"
        {
            self.init(doc: description[start...])
        }
        else
        {
            return nil
        }
    }
}
extension Doclink
{
    /// Parses a doclink from a string that does not include the `doc:` prefix.
    public
    init?(doc uri:Substring)
    {
        //  Count and trim the leading slashes. One leading slash is meaningless,
        //  two or more indicates a “bundle” root.
        var start:String.Index = uri.startIndex
        var slashes:Int = 0
        while start < uri.endIndex, uri[start] == "/"
        {
            if  slashes < 2
            {
                slashes += 1
                start = uri.index(after: start)
            }
            else
            {
                return nil
            }
        }

        let fragment:URI.Fragment?
        let end:String.Index

        if  let hashtag:String.Index = uri[start...].firstIndex(of: "#")
        {
            fragment = .init(decoding: uri[uri.index(after: hashtag)...])
            end = hashtag
        }
        else
        {
            fragment = nil
            end = uri.endIndex
        }

        if  let path:URI.Path = .init(relative: uri[start ..< end])
        {
            self.init(absolute: slashes >= 2,
                path: path.normalized(),
                fragment: fragment?.decoded)
        }
        else
        {
            return nil
        }
    }
}
