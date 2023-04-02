extension HTML
{
    @frozen public
    struct AttributeEncoder
    {
        @usableFromInline internal
        var utf8:[UInt8]

        @inlinable internal
        init(utf8:[UInt8] = [])
        {
            self.utf8 = utf8
        }
    }
}
extension HTML.AttributeEncoder
{
    /// Serializes an empty attribute, if the assigned boolean is true.
    /// Does nothing if it is false. The getter always returns false.
    @inlinable public
    subscript(name:HTML.Attribute) -> Bool
    {
        get
        {
            false
        }
        set(bool)
        {
            self[name] = bool ? "" : nil
        }
    }
    @inlinable public
    subscript(name:HTML.Attribute) -> String?
    {
        get
        {
            nil
        }
        set(text)
        {
            if  let text:String
            {
                self.utf8.append(0x20) // ' '
                self.utf8 += name.rawValue.utf8

                if  text.isEmpty
                {
                    return 
                }

                self.utf8.append(0x3D) // '='
                self.utf8.append(0x27) // '''

                for byte:UInt8 in text.utf8
                {
                    if  byte == 0x27
                    {
                        self.utf8 += "&#39;".utf8
                    }
                    else
                    {
                        self.utf8.append(byte)
                    }
                }

                self.utf8.append(0x27) // '''
            }
        }
    }
}
