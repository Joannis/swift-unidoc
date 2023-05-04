extension Compiler
{
    public
    struct UndefinedScalarError:Equatable, Error
    {
        public
        let resolution:ScalarSymbol

        public
        init(undefined resolution:ScalarSymbol)
        {
            self.resolution = resolution
        }
    }
}
extension Compiler.UndefinedScalarError:CustomStringConvertible
{
    public
    var description:String
    {
        "Undefined (or external) scalar '\(self.resolution)'."
    }
}
