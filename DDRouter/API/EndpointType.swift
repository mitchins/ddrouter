import Foundation

public protocol EndpointType {
    // base url to use - use this with NetworkEnvironment protocol
    // should not end in '/'
    var baseURL: URL { get }

    // path to endpoint - should start with '/'
    var path: String { get }

    // http method to use for request
    var method: HTTPMethod { get }

    // task (e.g. whether or not there are encodable parameters)
    // todo: this is silly imo, can be streamlined
    var task: HTTPTask { get }

    // headers
    var headers: HTTPHeaders? { get }

    // query parameters
    // todo: why is this one not typealiased the same as headers?
    var query: [String: String] { get }
}

public extension EndpointType {
    // Allowed character set for percent encoding of query values
    // Removing + sign from character set because + has a semantic value in url query
    var allowedQueryParameterCharacterSet: CharacterSet {
        return CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+"))
    }
}
