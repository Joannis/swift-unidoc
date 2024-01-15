import Atomics
import HTML
import HTTPServer
import IP
import URI

extension Swiftinit.LinkerPlugin
{
    struct StatusPage:Sendable
    {
        private
        let entries:[Swiftinit.EventBuffer<Swiftinit.Linker.Event>.Entry]

        init(entries:[Swiftinit.EventBuffer<Swiftinit.Linker.Event>.Entry])
        {
            self.entries = entries
        }
    }
}
extension Swiftinit.LinkerPlugin.StatusPage
{
    init(from buffer:Swiftinit.EventBuffer<Swiftinit.Linker.Event>)
    {
        //  This will be sent concurrently, so it will almost certainly
        //  end up being copied anyway.
        self.init(entries: [_].init(buffer.entries))
    }
}
extension Swiftinit.LinkerPlugin.StatusPage:Swiftinit.RenderablePage, Swiftinit.DynamicPage
{
    var title:String { "Linker plugin" }
}
extension Swiftinit.LinkerPlugin.StatusPage:Swiftinit.AdministrativePage
{
    public
    func main(_ main:inout HTML.ContentEncoder, format:Swiftinit.RenderFormat)
    {
        main[.h1] = "Linker plugin"
        main[.section, { $0.class = "events" }]
        {
            $0[.h2] = "Events"
            $0[.ol, { $0.class = "events" }]
            {
                for entry in self.entries.reversed()
                {
                    $0[.li]
                    {
                        $0[.p]
                        {
                            $0[.time]
                            {
                                $0.datetime = """
                                \(entry.timestamp.date)T\(entry.timestamp.time)Z
                                """
                            } = "\(entry.timestamp.date) \(entry.timestamp.time)"
                        }
                        $0[.p] = "\(entry.event)"
                    }
                }
            }
        }
    }
}
