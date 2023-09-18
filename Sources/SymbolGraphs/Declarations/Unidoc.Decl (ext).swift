import LexicalPaths
import Unidoc

extension Unidoc.Decl
{
    /// Returns all the components of the given path if an ``actor``, ``class``, ``enum``,
    /// ``protocol``, or ``struct``; returns all but the last component otherwise.
    @inlinable public
    func scope(trimming path:UnqualifiedPath) -> [String]
    {
        switch self
        {
        case    .actor,
                .class,
                .enum,
                .protocol,
                .struct,
                .macro(.attached):
            return path.map { $0 }

        case    .associatedtype,
                .case,
                .deinitializer,
                .func,
                .initializer,
                .operator,
                .subscript,
                .typealias,
                .var,
                .macro(.freestanding):
            return path.prefix
        }
    }
}
