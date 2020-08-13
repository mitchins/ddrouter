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
    
    // Giving the option to encode plus sign for queries
    // https://developer.apple.com/documentation/foundation/nsurlcomponents/1407752-queryitems
    var encodePlusSignInQuery: Bool { get }
}


