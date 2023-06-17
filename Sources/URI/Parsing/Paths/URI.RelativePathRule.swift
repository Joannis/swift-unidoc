import Grammar

extension URI
{
    /// A parsing rule that matches a relative path, such as
    /// `foo/bar/baz`. Parsing an absolute path with this
    /// rule will generate a path with an empty leading path vector.
    ///
    /// Parsing a root expression (`/`) with this rule produces
    /// a path with two nil path vectors.
    enum RelativePathRule<Location>
    {
    }
}
extension URI.RelativePathRule:ParsingRule
{
    typealias Terminal = UInt8

    static
    func parse<Source>(
        _ input:inout ParsingInput<some ParsingDiagnostics<Source>>) throws -> URI.Path
        where Source:Collection<UInt8>, Source.Index == Location
    {
        var components:[URI.Path.Component] =
        [
            try input.parse(as: URI.PathComponentRule<Location>.self)
        ]
        while let next:URI.Path.Component = input.parse(as: URI.PathElementRule<Location>?.self)
        {
            components.append(next)
        }
        return .init(components: components)
    }
}
