import PackageGraphs
import SemanticVersions

extension Driver
{
    @frozen public
    struct Toolchain
    {
        public
        let version:SemanticVersionMask?
        public
        let triple:Triple

        @inlinable public
        init(version:SemanticVersionMask?, triple:Triple)
        {
            self.version = version
            self.triple = triple
        }
    }
}
extension Driver.Toolchain
{
    init(parsing splash:String) throws
    {
        //  Splash should consist of two complete lines of the form
        //
        //  Swift version 5.8 (swift-5.8-RELEASE)
        //  Target: x86_64-unknown-linux-gnu
        let lines:[Substring] = splash.split(separator: "\n", omittingEmptySubsequences: false)
        //  if the final newline isn’t present, the output was clipped.
        guard lines.count == 3
        else
        {
            throw Driver.ToolchainError.malformedSplash
        }

        let toolchain:[Substring] = lines[0].split(separator: " ")
        let triple:[Substring] = lines[1].split(separator: " ")

        guard   toolchain.count == 4,
                toolchain[0 ... 1] == ["Swift", "version"],
                triple.count == 2,
                triple[0] == "Target:"
        else
        {
            throw Driver.ToolchainError.malformedSplash
        }

        if  let triple:Triple = .init(triple[1])
        {
            self.init(version: .init(String.init(toolchain[2])), triple: triple)
        }
        else
        {
            throw Driver.ToolchainError.malformedTriple
        }
    }
}
extension Driver.Toolchain
{
    func platform() throws -> PlatformIdentifier
    {
        if      self.triple.os.starts(with: "linux")
        {
            return .linux
        }
        else if self.triple.os.starts(with: "ios")
        {
            return .iOS
        }
        else if self.triple.os.starts(with: "macos")
        {
            return .macOS
        }
        else if self.triple.os.starts(with: "tvos")
        {
            return .tvOS
        }
        else if self.triple.os.starts(with: "watchos")
        {
            return .watchOS
        }
        else if self.triple.os.starts(with: "windows")
        {
            return .windows
        }
        else
        {
            throw Driver.ToolchainError.unsupportedTriple(self.triple)
        }
    }
}
