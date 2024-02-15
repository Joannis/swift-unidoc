import MarkdownABI

extension Markdown
{
    /// Not to be confused with ``Markdown.BlockElement``.
    @frozen public
    enum InlineElement
    {
        case autolink(InlineAutolink)

        case container(InlineContainer<Self>)

        case code(InlineCode)
        case html(InlineHTML)
        case link(InlineHyperlink)
        case image(InlineImage)

        case reference(Int)

        case text(String)
    }
}
extension Markdown.InlineElement:Markdown.TreeElement
{
    @inlinable public
    func emit(into binary:inout Markdown.BinaryEncoder)
    {
        switch self
        {
        case .autolink(let autolink):
            autolink.element.emit(into: &binary)

        case .container(let container):
            container.emit(into: &binary)

        case .code(let code):
            code.emit(into: &binary)

        case .html(let html):
            html.emit(into: &binary)

        case .image(let image):
            image.emit(into: &binary)

        case .link(let link):
            link.emit(into: &binary)

        case .reference(let reference):
            binary &= reference

        case .text(let unescaped):
            binary += unescaped
        }
    }
}
extension Markdown.InlineElement:Markdown.TextElement
{
    @inlinable public static
    func += (text:inout String, self:Self)
    {
        switch self
        {
        case .autolink(let autolink):   text += autolink.text
        case .container(let container): text += container
        case .code(let code):           text += code
        case .html:                     return
        case .image(let image):         text += image
        case .link(let link):           text += link
        case .reference:                return
        case .text(let part):           text += part
        }
    }

    @inlinable public mutating
    func outline(by register:(Markdown.InlineAutolink) throws -> Int?) rethrows
    {
        switch self
        {
        case .autolink(let autolink):
            if  let reference:Int = try register(autolink)
            {
                self = .reference(reference)
            }

        case .container(var container):
            self = .text("")
            defer { self = .container(container) }
            try container.outline(by: register)

        case .link(var link):
            self = .text("")
            defer { self = .link(link) }
            try link.outline(by: register)

        case .code, .html, .image, .reference, .text:
            return
        }
    }
}
extension Markdown.InlineElement
{
    /// Returns true if this element can appear as link text.
    @inlinable internal
    var anchorable:Bool
    {
        switch self
        {
        case .autolink:                 false
        case .container(let container): container.anchorable
        case .code:                     true
        case .html:                     false
        case .image:                    false
        case .link:                     false
        case .reference:                false
        case .text:                     true
        }
    }
}
