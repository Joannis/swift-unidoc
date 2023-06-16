import BSONDecoding
import BSONEncoding
import Sources

extension SourceLocation<Int32>:BSONEncodable, BSONWeakEncodable
{
    public
    func encode(to field:inout BSON.Field)
    {
        (self.file .. self.position).encode(to: &field)
    }
}
extension SourceLocation<Int32>:BSONDecodable
{
    @inlinable public
    init(bson:BSON.AnyValue<some RandomAccessCollection<UInt8>>) throws
    {
        self = try bson.cast
        {
            if case .int64(let int64) = $0
            {
                return .init(position: .init(rawValue: .init(truncatingIfNeeded: int64)),
                    file: .init(int64 >> 32))
            }
            else
            {
                return nil
            }
        }
    }
}
