import JSONDecoding
import ModuleGraphs
import SemanticVersions

public
struct PackageManifest:Equatable, Sendable
{
    /// The name of the package. This is *not* always the same as the package’s
    /// identity, but often is.
    public
    let name:String
    public
    let root:Repository.Root
    public
    let requirements:[PlatformRequirement]
    public
    let dependencies:[Dependency]
    public
    let products:[Product]
    public
    let targets:[Target]
    /// The `swift-tools-version` format of this manifest.
    public
    let format:SemanticVersion

    @inlinable public
    init(name:String,
        root:Repository.Root,
        requirements:[PlatformRequirement] = [],
        dependencies:[Dependency] = [],
        products:[Product] = [],
        targets:[Target] = [],
        format:SemanticVersion)
    {
        self.name = name
        self.root = root
        self.requirements = requirements
        self.dependencies = dependencies
        self.products = products
        self.targets = targets
        self.format = format
    }
}
extension PackageManifest
{
    public
    init(parsing json:String) throws
    {
        try self.init(json: try JSON.Object.init(parsing: json))
    }
}
extension PackageManifest:JSONObjectDecodable
{
    public
    enum CodingKeys:String
    {
        case dependencies
        case name
        case products

        case root = "packageKind"
        enum Root:String
        {
            case root
        }

        case requirements = "platforms"
        case targets

        case format = "toolsVersion"
        enum Format:String
        {
            case version = "_version"
        }
    }
    public
    init(json:JSON.ObjectDecoder<CodingKeys>) throws
    {
        self.init(
            name: try json[.name].decode(),
            root: try json[.root].decode(as: JSON.ObjectDecoder<CodingKeys.Root>.self)
            {
                try $0[.root].decode(
                    as: JSON.SingleElementRepresentation<Repository.Root>.self,
                    with: \.value)
            },
            requirements: try json[.requirements].decode(),
            dependencies: try json[.dependencies].decode(),
            products: try json[.products].decode(),
            targets: try json[.targets].decode(),
            format: try json[.format].decode(as: JSON.ObjectDecoder<CodingKeys.Format>.self)
            {
                try $0[.version].decode(as: JSON.StringRepresentation<SemanticVersion>.self,
                    with: \.value)
            })
    }
}
