//
//  Alamofire+SyncRequest.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/12/18.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation
import Alamofire

class MBURLSessionManager {
    static let `default` = { () -> SessionManager in
        let configuration: URLSessionConfiguration = {
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = HTTPHeaders.defaultValue()
            configuration.requestCachePolicy = .useProtocolCachePolicy
            configuration.urlCache = MBURLCache.sharedCache

            return configuration
        }()

        let manager = SessionManager(configuration: configuration)

        return manager
    }()
}

class MBURLCache {
    static let sharedCache = URLCache(memoryCapacity: 0, diskCapacity: 50 * 1024 * 1024)
}

extension URLConvertible {

    public func syncRequestJSON(
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil,
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData)
        -> DataResponse<Any> {
            var responseData: DataResponse<Any>? = nil
            DispatchGroup.wait { dispatchGroup in
                guard let urlString = self as? String else {
                    dispatchGroup.leave()
                    return
                }
                var request = URLRequest(url: URL(string: urlString)!, cachePolicy: cachePolicy, timeoutInterval: 10)
                request.httpMethod = method.rawValue
                request.allHTTPHeaderFields = headers
                let encodedURLRequest = try! encoding.encode(request, with: parameters)
                if cachePolicy == .useProtocolCachePolicy {
                    if let rsp = MBURLCache.sharedCache.cachedResponse(for: encodedURLRequest), let httpResponse = rsp.response as? HTTPURLResponse {
                        UI.log(verbose: "Found HTTP Cache. Request=[\(encodedURLRequest.description)], ResponseDate=[\(httpResponse.allHeaderFields["Date"] ?? "")].")
                        if !self.isDataExpired(requestHeaders: headers, response: httpResponse) {
                            let result = Request.serializeResponseJSON(options: .allowFragments, response: rsp.response as? HTTPURLResponse, data: rsp.data, error: nil)
                            responseData = DataResponse<Any>(request: encodedURLRequest, response: httpResponse, data: rsp.data, result: result)
                            dispatchGroup.leave()
                            return
                        } else {
                            UI.log(verbose: "Cached Data Expired. Request=[\(encodedURLRequest.description)] .")
                        }
                    }
                }
                
                MBURLSessionManager.default.request(encodedURLRequest).responseJSON(queue: DispatchQueue(label: "Alamofire Sync")) { response in
                    responseData = response
                    if (cachePolicy == .returnCacheDataElseLoad
                        || cachePolicy == .returnCacheDataDontLoad
                        || cachePolicy == .useProtocolCachePolicy) {
                        // Wait for URLCache store cache asynchronously
                        if let httpResponse = response.response, let data = response.data, httpResponse.statusCode == 200 {
                            DispatchQueue.global().async {
                                UI.log(verbose: "Save response to cache. Request URL=[\(httpResponse.url?.description ?? "")].")
                                MBURLCache.sharedCache.storeCachedResponse(CachedURLResponse(response: httpResponse, data: data), for: encodedURLRequest)
                            }
                        }
                    }
                    dispatchGroup.leave()
                }
            }

            return responseData!
    }

    public func syncRequestString(
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil)
        -> DataResponse<String> {
            var responseData: DataResponse<String>? = nil
            DispatchGroup.wait { dispatchGroup in
                Alamofire.request(self, method: method, parameters: parameters, encoding: encoding, headers: headers).responseString(queue: DispatchQueue(label: "Alamofire Sync")) { response in
                    responseData = response
                    dispatchGroup.leave()
                }
            }
            return responseData!
    }
    
    @discardableResult
    public func syncDownloadFile(to destinationURL: URL) -> DefaultDownloadResponse? {
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (destinationURL, [.removePreviousFile, .createIntermediateDirectories])
        }
        var responseData: DefaultDownloadResponse? = nil;
        DispatchGroup.wait { dispatchGroup in
            DispatchQueue.global(qos: .default).async {
                Alamofire.download(self, method: .get, parameters: nil, encoding: URLEncoding.default, headers: nil, to: destination).response(queue: DispatchQueue(label: "Alamofire Sync")) {
                    response in
                    responseData = response
                    dispatchGroup.leave()
                }
            }
        }
        return responseData
    }
    
    public func syncDownloadFile(to destination: DownloadRequest.DownloadFileDestination?) {
        Alamofire.download(self, method: .get, parameters: nil, encoding: URLEncoding.default, headers: nil, to: destination)
    }
    
    public func syncUploadMultiPartFormJSON(
        method: HTTPMethod = .post,
        parameters: [String: Data],
        files: [String: URL]? = nil,
        headers: HTTPHeaders? = nil)
        -> DataResponse<Any>  {
        var responseData: DataResponse<Any>!
        DispatchGroup.wait { group in
            SessionManager.default.upload(multipartFormData: { multipartFormData in
                for (key, value) in parameters {
                    multipartFormData.append(value, withName: key)
                }
                for (key, value) in files ?? [:] {
                    multipartFormData.append(value, withName: key)
                }
            }, to: self, method: .post, headers: headers, queue: DispatchQueue.global()) { encodingResult in
                switch encodingResult {
                    case .success(let upload, _, _):
                        upload.responseJSON(queue: DispatchQueue(label: "Alamofire Sync")) { response in
                            responseData = response
                            group.leave()
                        }
                    case .failure(let error):
                        responseData = DataResponse<Any>(request: nil, response: nil, data: nil, result: Result.failure(error))
                        group.leave()
                @unknown default:
                    fatalError()
                }
            }
        }
        return responseData
    }
    
    private func dateFromServer(dateString: String?) -> Date? {
        guard dateString != nil else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        formatter.locale = Locale(identifier: "en-US")
        return formatter.date(from: dateString!)
    }
    
    private func isDataExpired(requestHeaders: HTTPHeaders?, response: HTTPURLResponse) -> Bool {
        if let cacheDate = self.dateFromServer(dateString: response.allHeaderFields["Date"] as? String),
           let cacheControl = response.allHeaderFields["Cache-Control"] as? String ?? requestHeaders?["Cache-Control"] {
            let maxAge = cacheControl.replacingOccurrences(of: "max-age=", with: "")
            let maxAgeValue = maxAge.double() ?? 0
//            print("\(Date().timeIntervalSince1970) - \(cacheDate.timeIntervalSince1970) = \(Date().timeIntervalSince1970 - cacheDate.timeIntervalSince1970)")
            return Date().timeIntervalSince1970 - cacheDate.timeIntervalSince1970 >= maxAgeValue
        }
        return true
    }
}
