extension Compiler.Scalars
{
    enum Recognition
    {
        /// Scalar will be excluded from the symbol graph. Edges connected to
        /// an excluded scalar will be pruned.
        case excluded
        /// Scalar will be included in the symbol graph.
        case included(Compiler.ScalarReference)
        /// Scalar *may* be included in the symbol graph. This is a terminal
        /// state if the scalar is from a foreign module.
        case recorded(String)
    }
}
