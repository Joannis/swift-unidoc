extension Swiftinit
{
    typealias CollapsibleContent = _SwiftinitCollapsibleContent
}
protocol _SwiftinitCollapsibleContent
{
    /// The number of **visible** list items.
    var length:Int { get }
    /// The number of **all** list items, hidden or visible.
    var count:Int { get }
}
