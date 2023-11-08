import UnidocProfiling

extension ServerProfile.ByClient
{
    subscript(annotation:Server.ClientAnnotation) -> Int
    {
        _read
        {
            yield  self[keyPath: annotation.field]
        }
        _modify
        {
            yield &self[keyPath: annotation.field]
        }
    }
}
