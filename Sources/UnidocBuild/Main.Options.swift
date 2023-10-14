import ModuleGraphs

extension Main
{
    struct Options
    {
        var package:PackageIdentifier
        var cookie:String
        var remote:String
        var port:Int

        var pretty:Bool
        var build:Bool
        var force:Bool

        private
        init(package:PackageIdentifier)
        {
            self.package = package
            self.cookie = ""
            self.remote = "swiftinit.org"
            self.port = 443

            self.pretty = false
            self.build = true
            self.force = false
        }
    }
}
extension Main.Options
{
    static
    func parse() throws -> Self
    {
        var arguments:ArraySlice<String> = CommandLine.arguments[1...]

        guard
        let package:String = arguments.popFirst()
        else
        {
            fatalError("Usage: \(CommandLine.arguments[0]) <package>")
        }

        var options:Self = .init(package: .init(package))

        while let option:String = arguments.popFirst()
        {
            switch option
            {
            case "--cookie", "-i":
                guard
                let cookie:String = arguments.popFirst()
                else
                {
                    fatalError("Expected cookie after '\(option)'")
                }

                options.cookie = cookie

            case "--remote", "-h":
                guard
                let remote:String = arguments.popFirst()
                else
                {
                    fatalError("Expected remote hostname after '\(option)'")
                }

                options.remote = remote

            case "--port", "-p":
                guard
                let port:String = arguments.popFirst(),
                let port:Int = .init(port)
                else
                {
                    fatalError("Expected port number after '\(option)'")
                }

                options.port = port

            case "--pretty", "-P":
                options.pretty = true

            case "--force", "-f":
                options.force = true

            case "--uplink-only", "-u":
                options.build = false

            case let option:
                fatalError("Unknown option '\(option)'")
            }
        }

        return options
    }
}
