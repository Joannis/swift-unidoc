import HTML
import SwiftinitRender
import UnidocDB
import UnixTime
import URI

extension Swiftinit
{
    struct PackagesCreatedPage
    {
        private
        let packages:[Unidoc.PackageMetadata]
        private
        let date:Timestamp.Date

        init(packages:[Unidoc.PackageMetadata], on date:Timestamp.Date)
        {
            self.packages = packages
            self.date = date
        }
    }
}
extension Swiftinit.PackagesCreatedPage:Swiftinit.RenderablePage
{
    var title:String { "Packages · \(self.date)" }
}
extension Swiftinit.PackagesCreatedPage:Swiftinit.StaticPage
{
    var location:URI { Swiftinit.Telescope[self.date] }
}
extension Swiftinit.PackagesCreatedPage:Swiftinit.ApplicationPage
{
    func main(_ main:inout HTML.ContentEncoder, format:Swiftinit.RenderFormat)
    {
        main[.section, { $0.class = "introduction" }]
        {
            $0[.h1] = self.date.short(.en)
        }

        main[.section, { $0.class = "details" }]
        {
            if  self.packages.isEmpty
            {
                $0[.p] = "No Swift repositories were created on \(self.date.long(.en))."
                return
            }

            $0[.ol, { $0.class = "packages" }]
            {
                for package:Unidoc.PackageMetadata in self.packages
                {
                    $0[.li]
                    {
                        $0[.a]
                        {
                            $0.href = "\(Swiftinit.Tags[package.symbol])"
                        } = "\(package.symbol)"
                    }
                }
            }
        }
    }
}
