import HTML
import UnidocRecords
import URI

struct ModuleSidebar
{
    private
    let context:any VersionedPageContext

    let nouns:[Volume.Noun]

    init(_ context:any VersionedPageContext, nouns:[Volume.Noun])
    {
        self.context = context

        self.nouns = nouns
    }
}
extension ModuleSidebar:HyperTextOutputStreamable
{
    static
    func += (html:inout HTML.ContentEncoder, self:Self)
    {
        //  Unfortunately, this cannot be a proper `ul`, because `ul` cannot contain another
        //  `ul` as a direct child.
        html[.div, { $0.class = "nountree" }]
        {
            var previous:Volume.Stem = ""
            var depth:Int = 1

            for noun:Volume.Noun in self.nouns
            {
                let (name, indents):(Substring, Int) = noun.shoot.stem.relative(to: previous)

                if  indents < depth
                {
                    for _:Int in indents ..< depth
                    {
                        $0.close(.div)
                    }
                }
                else
                {
                    for _:Int in depth ..< indents
                    {
                        $0.open(.div) { $0.class = "indent" }
                    }
                }

                previous = noun.shoot.stem
                depth = indents

                var uri:URI { Site.Docs[self.context.volume, noun.shoot] }

                switch noun.style
                {
                case .text(let text):
                    $0[.a] { $0.href = "\(uri)" ; $0.class = "text" } = text

                case .stem(let citizenship):
                    //  The URI is only valid if the principal volume API version is at
                    //  least 1.0!
                    if  case .foreign = citizenship,
                        self.context.volume.api < .v(1, 0)
                    {
                        $0[.span] = name
                    }
                    else
                    {
                        $0[.a]
                        {
                            $0.href = "\(uri)"

                            switch citizenship
                            {
                            case .culture:  break
                            case .package:  $0.class = "extension local"
                            case .foreign:  $0.class = "extension foreign"
                            }

                        } = name
                    }
                }
            }
            for _:Int in 1 ..< depth
            {
                $0.close(.div)
            }
        }
    }
}
