import Foundation
import RxSwift

public class DDRouter {
    static var sharedSession: URLSession?
    static var printToConsole = false

    // must call this
    public static func initialise(
        configuration: URLSessionConfiguration,
        printToConsole: Bool = false) {

        sharedSession = URLSession(configuration: configuration)
        Self.printToConsole = printToConsole
    }
}

public protocol RouterProtocol {
    associatedtype Endpoint: EndpointType
    associatedtype E: APIErrorModelProtocol
    func request<T: Decodable>(_ route: Endpoint) -> Single<T>
    func requestData(_ route: Endpoint) -> Single<DataOrEmpty>
    func uploadData<T: Decodable>(_ route: Endpoint, data: Data) -> Single<T>
    init(ephemeralSession: Bool)
}

public struct EmptyStruct: Decodable {}

public enum DataOrEmpty {
    case data(Data)
    case empty
}

extension RouterProtocol {
    public typealias Empty = EmptyStruct
}

public class Router<Endpoint: EndpointType, E: APIErrorModelProtocol>: RouterProtocol {

    var urlSession: URLSession?

    required public init(ephemeralSession: Bool = false) {
        if ephemeralSession {
            // Clone the current session config, then mutate as needed. We won't capture changes made _after_ init(). Ok normally.
            if let masterConfiguration = DDRouter.sharedSession?.configuration {
                let tempConfiguration = URLSessionConfiguration.ephemeral
                // Allow monkey patching from the main configuration such as Stubbing etc
                tempConfiguration.protocolClasses = masterConfiguration.protocolClasses
                urlSession = URLSession(configuration: tempConfiguration)
            }
        } else {
            urlSession = DDRouter.sharedSession
        }
    }

    // todo: do this in the future
    // https://medium.com/@danielt1263/retrying-a-network-request-despite-having-an-invalid-token-b8b89340d29

    // this returns a single that will always subscribe on a background thread
    // and observe on the main thread

    public func request<T: Decodable>(_ route: Endpoint) -> Single<T> {
        return requestData(route).flatMap(jsonResponseHandler)
    }

    public func requestData(_ route: Endpoint) -> Single<DataOrEmpty> {
        return Single.create { [weak self] single in
            guard let self = self else {
                single(.error(APIError<E>.unknownError))
                return Disposables.create()
            }

            var task: URLSessionTask?

            // try to build the request
            let request: URLRequest
            do {
                request = try self.buildRequest(from: route)
            }
            catch let error {
                single(.error(error))
                return Disposables.create()
            }

            // log the request
            // todo: log properly
            if DDRouter.printToConsole {
                NetworkLogger.log(request: request)
            }

            // get the session
            guard let urlSession = self.urlSession else {
                single(.error(APIError<E>.unknownError))
                return Disposables.create()
            }
            
            // perform the request
            task = urlSession.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                single(self.responseHandler(data: data, response: response, error: error))
            }
            task?.resume()

            return Disposables.create {
                task?.cancel()
            }
        }
        .subscribeOn(SerialDispatchQueueScheduler(qos: .background))
        .observeOn(MainScheduler.instance)
    }
    
    public func uploadData<T: Decodable>(_ route: Endpoint, data: Data) -> Single<T> {
        return uploadData(route, from: data).flatMap(jsonResponseHandler)
    }
    
    public func uploadData(_ route: Endpoint, from uploadData: Data) -> Single<DataOrEmpty> {
        return Single.create { [weak self] single in
            guard let self = self else {
                single(.error(APIError<E>.unknownError))
                return Disposables.create()
            }
            
            var task: URLSessionTask?
            
            // try to build the request
            let request: URLRequest
            do {
                request = try self.buildRequest(from: route)
            }
            catch let error {
                single(.error(error))
                return Disposables.create()
            }

            // log the request
            // todo: log properly
            if DDRouter.printToConsole {
                NetworkLogger.log(request: request)
            }

            // get the session
            guard let urlSession = self.urlSession else {
                single(.error(APIError<E>.unknownError))
                return Disposables.create()
            }
            // perform the request
            task = urlSession.uploadTask(with: request, from: uploadData)  { [weak self] data, response, error in
                guard let self = self else { return }
                single(self.responseHandler(data: data, response: response, error: error))
            }
            task?.resume()

            return Disposables.create {
                task?.cancel()
            }
        }
        .subscribeOn(SerialDispatchQueueScheduler(qos: .background))
        .observeOn(MainScheduler.instance)
    }
    
    private func responseHandler(data: Data?, response: URLResponse?, error: Error?) -> SingleEvent<DataOrEmpty> {
        // return any error from the url session task - todo: wrap this error
        if let error = error {
            return .error(error)
        }

        // get the response body or throw null data error
        // todo: technically should throw different error if
        // first cast fails
        guard
            let response = response as? HTTPURLResponse,
            let responseData = data else {

            return .error(APIError<E>.nullData)
        }

        // print response
        if DDRouter.printToConsole {

            // log response - todo: proper logging
            NetworkLogger.log(response: response)

            // print response data
            Router.printJSONData(data: responseData)
        }

        // response switch
        switch response.statusCode {

        // 204 success but no content at all
        case 204:
            // Canonical type for empty as defined by us
            return .success(DataOrEmpty.empty)
        // 2xx success.
        case 200...203, 205...299:
            return .success(DataOrEmpty.data(responseData))
        // 4xx client errors
        case 400...499:

            // match the actual status code (or unknown error)
            let statusCode = HTTPStatusCode(rawValue: response.statusCode)
            switch statusCode {

            // bad request
            case .badRequest:
                let error = try? JSONDecoder().decode(
                    E.self,
                    from: responseData)
                return .error(APIError<E>.badRequest(error))

            // unauthorized
            case .unauthorized:
                let error = try? JSONDecoder().decode(
                    E.self,
                    from: responseData)
                return .error(APIError<E>.unauthorized(error))
                // todo: add autoretry back, outside this function

            // resource not found
            case .notFound:
                return .error(APIError<E>.notFound)

            // too many requests
            case .tooManyRequests:
                let error = try? JSONDecoder().decode(
                    E.self,
                    from: responseData)
                return .error(APIError<E>.tooManyRequests(error))

            // forbidden
            case .forbidden:
                let error = try? JSONDecoder().decode(
                    E.self,
                    from: responseData)
                return .error(APIError<E>.forbidden(error))

            // unknown
            default:
                if let error = try? JSONDecoder().decode(
                    E.self,
                    from: responseData) {
                    return .error(APIError<E>.other4xx(error))
                } else {
                    return .error(APIError<E>.unknownError)
                }
            }

        // 5xx server error
        case 500...599:
            let error = try? JSONDecoder().decode(
                E.self,
                from: responseData)
            return .error(APIError<E>.serverError(error))

        // default / unknown error
        default:
            return .error(APIError<E>.unknownError)
        }
    }
    
    private func jsonResponseHandler<T: Decodable>(result: DataOrEmpty) -> Single<T> {
        switch result {
        case let .data(data):
            return Single<T>.create { single in
                do {
                    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                    single(.success(decodedResponse))
                    return Disposables.create()
                }
                catch (let error) {
                    single(.error(APIError<E>.serializeError(error)))
                    return Disposables.create()
                }
            }
        case .empty:
            return Single<T>.create { single in
                if let empty = Empty() as? T {
                    single(.success(empty))
                } else {
                    single(.error(APIError<E>.unknownError))
                }
                return Disposables.create()
            }
        }
    }

    // build URLRequest from a given endpoint route
    private func buildRequest(from route: EndpointType) throws -> URLRequest {

        guard let urlSession = self.urlSession,
            var urlComponents = URLComponents(
            url: route.baseURL.appendingPathComponent(route.path),
            resolvingAgainstBaseURL: true) else {
                throw APIError<E>.internalError
        }
        
        // Build query
        if !route.query.isEmpty {
            let items = route.query.map { URLQueryItem(name: $0, value: $1) }
            urlComponents.queryItems = items
        }
        
        if route.encodePlusSignInQuery {
            urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        }

        // get the url
        guard let url = urlComponents.url else {
            throw APIError<E>.internalError
        }

        // create a request
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: urlSession.configuration.timeoutIntervalForRequest)

        // method
        request.httpMethod = route.method.rawValue

        // headers
        if let additionalHeaders = route.headers {
            Router.addAdditionalHeaders(additionalHeaders, request: &request)
        }

        // content type
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // encode parameters
        switch route.task {
        case .request:
            break

        case .requestEncodableParameters(
            let bodyParameters,
            let urlParameters):

            do {
                try ParameterEncoding.encode(
                    urlRequest: &request,
                    bodyParameters: bodyParameters,
                    urlParameters: urlParameters)
            }
            catch let error {
                throw APIError<E>.serializeError(error)
            }
        }
        return request
    }

    private static func addAdditionalHeaders(
        _ additionalHeaders: HTTPHeaders?,
        request: inout URLRequest) {

        guard let headers = additionalHeaders else { return }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    // todo: move to NetworkLogger
    private static func printJSONData(data: Data) {

        guard
            let object = try? JSONSerialization.jsonObject(
                with: data,
                options: []),
            let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted]),
            let prettyPrintedString = NSString(
                data: data,
                encoding: String.Encoding.utf8.rawValue) else {

                // todo: consistent error logging
                print("----- Error in Json Response")
                return
        }

        print(prettyPrintedString)
    }
}

