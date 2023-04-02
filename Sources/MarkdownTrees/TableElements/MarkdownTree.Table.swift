import MarkdownABI

extension MarkdownTree
{
    public final
    class Table:Block
    {
        public
        var head:Row<HeaderCell>
        public
        var body:[[BodyCell]]

        public
        init(columns:[Alignment?] = [], head:[HeaderCell], body:[[BodyCell]])
        {
            self.head = .init(alignments: columns, cells: head)
            self.body = body
        }

        /// Emits a `table` element.
        public override
        func emit(into binary:inout MarkdownBinary)
        {
            binary[.table]
            {
                $0[.thead] = self.head
                $0[.tbody]
                {
                    for row:Row<BodyCell> in self
                    {
                        row.emit(into: &$0)
                    }
                }
            }
        }
    }
}
extension MarkdownTree.Table
{
    @inlinable public
    var columns:[Alignment?]
    {
        _read
        {
            yield  self.head.alignments
        }
        _modify
        {
            yield &self.head.alignments
        }
    }
}
extension MarkdownTree.Table:RandomAccessCollection
{
    @inlinable public
    var startIndex:Int
    {
        self.body.startIndex
    }
    @inlinable public
    var endIndex:Int
    {
        self.body.endIndex
    }
    @inlinable public
    subscript(row:Int) -> Row<BodyCell>
    {
        .init(alignments: self.columns, cells: self.body[row])
    }
}
