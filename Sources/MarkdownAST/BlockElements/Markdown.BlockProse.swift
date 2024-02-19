import MarkdownABI

extension Markdown
{
    open
    class BlockProse:BlockElement
    {
        public final
        var elements:[InlineElement]

        @inlinable public
        init(_ elements:[InlineElement])
        {
            self.elements = elements
        }

        /// Emits the elements in this container, with no framing.
        @inlinable open override
        func emit(into binary:inout Markdown.BinaryEncoder)
        {
            for element:InlineElement in self.elements
            {
                element.emit(into: &binary)
            }
        }

        /// Calls the superclass method, and then calls ``Markdown.TreeElement/outline(by:)``
        /// on each of the inline elements in this container.
        @inlinable public final override
        func outline(by register:(Markdown.AnyReference) throws -> Int?) rethrows
        {
            try super.outline(by: register)
            for index:Int in self.elements.indices
            {
                try self.elements[index].outline(by: register)
            }
        }

        /// Does absolutely nothing, except call the superclass method.
        @inlinable public final override
        func traverse(with visit:(Markdown.BlockElement) throws -> ()) rethrows
        {
            try super.traverse(with: visit)
        }
    }
}
