import HTML
import Unidoc

extension Inliner
{
    struct Breadcrumbs
    {
        private
        let scope:VectorLink<[Substring], [Unidoc.Scalar]>?
        private
        let last:Substring

        init(
            scope:VectorLink<[Substring], [Unidoc.Scalar]>?,
            last:Substring)
        {
            self.scope = scope
            self.last = last
        }
    }
}
extension Inliner.Breadcrumbs:HyperTextOutputStreamable
{
    static
    func += (html:inout HTML.ContentEncoder, self:Self)
    {
        html[.div, { $0.class = "breadcrumbs" }]
        {
            if  let scope:Inliner.VectorLink<[Substring], [Unidoc.Scalar]> = self.scope
            {
                $0 += scope
                $0 += "."
            }

            $0[.span] = self.last
        }
    }
}
