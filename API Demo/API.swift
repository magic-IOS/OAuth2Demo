
import UIKit
import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public typealias APICompletion = (_ response: [String: Any]?, _ error: Error?) -> Void
public typealias APIRetryBlock = (_ shouldRetry: Bool, _ delay: Double) -> Void

public protocol APIRetrier {
    func shouldRetry(request: URLRequest, response: URLResponse?, completion: @escaping APIRetryBlock)
}

class API {
    public static let shared: API = API()
    public let session: URLSession
    
    private var acceptableStatusCodes: [Int] = Array(200..<300)
    private let apiCallQueue = DispatchQueue(label: "com.API.apiCallQueue")
    
    private var activeRetriers: [OAuth2Handler] = []
    
    // MARK: - INIT
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 120 // seconds
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Helpers
    func headers() -> [String: String] {
        
        return [
            "Content-Type":"application/json",
            "Authorization":"Bearer \(getAuthToken())"
        ]
    }
    
    private func headersImage() -> [String: String] {
        
        return [
            "Authorization": "Bearer \(getAuthToken())",
        "Content-Type": "multipart/form-data" ]
    }
    
    func getAuthToken() -> String {
        let strAuthToken:String = "cjydrd0p27ry8irvcjj9a420krh3g7yw"
        
        
        return strAuthToken
    }
    
    func getRefreshToken() -> String! {
        let strAuthToken:String = ""
        
        return strAuthToken
    }
    
    func body(dictParam:[String:Any]) -> Data {
        /*var param : [String:Any] = [String:Any]()
        var localTimeZoneName: String { return TimeZone.current.identifier }
        param["timezone"] = localTimeZoneName
        for (key, value) in dictParam {
            param[key] = value
        }*/
        var data = Data()
        do {
            data = try JSONSerialization.data(withJSONObject: dictParam, options: [])
        }catch{
            
        }
        return data
    }
    
    
    // MARK: - Convenience
    @discardableResult
    public func request(useRefreshToken: Bool = true, method: HTTPMethod, url: String, body: Data?, completion: @escaping APICompletion) -> URLSessionTask {
        
        let authHandler = OAuth2Handler(accessToken: self.getAuthToken(),
                                        refreshToken: self.getRefreshToken())
        authHandler.useRefreshToken = useRefreshToken
        
        let headers = self.headers()
        let request = self.formattedRequest(url: url, method: method, headers: headers, body: body)
        
        let task = self.session.dataTask(with: request, completionHandler: { (data, response, error) in
            self.debugResponsePrint(url: url, method: method, headers: headers, body: body, response: response, error: error, data: data)
            self.apiCallQueue.async {
                guard self.validate(response: response, with: error, optionallyRetry: request, authHandler: authHandler, useRefreshToken: useRefreshToken, method: method, url: url, body: body, completion: completion) else {
                    return }
                
                do {
                    guard let data = data, error == nil else {
                        DispatchQueue.main.async { completion(nil, error) }
                        return
                    }
                    
                    let dictionary = try JSONSerialization.jsonObject(with: data)
                    if(dictionary is [[String:Any]]) {
                        let dict = ["data":dictionary]
                        
                        DispatchQueue.main.async { completion(dict, nil) }
                    }else {
                        DispatchQueue.main.async { completion(dictionary as? [String:Any], nil) }
                        // let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode
                    }
                    
                }
                catch {
                    DispatchQueue.main.async { completion(nil, error) }
                }
            }
        })
        
        task.resume()
        
        return task
        
    }
    
    @discardableResult
    public func unqualifiedRequest(url: String, method: HTTPMethod, headers: [String: String], body: Data?, completion: @escaping APICompletion) -> URLSessionTask {
        
        let request = self.formattedRequest(url: url, method: method, headers: headers, body: body)
        
        let task = self.session.dataTask(with: request, completionHandler: { (data, response, error) in
            self.debugResponsePrint(url: url, method: method, headers: headers, body: body, response: response, error: error, data: data)
            self.apiCallQueue.async {
                guard let data = data, error == nil else {
                    DispatchQueue.main.async { completion(nil, error) }
                    return
                }
                
                do {
                    let dictionary = try JSONSerialization.jsonObject(with: data)
                    if(dictionary is [[String:Any]]) {
                        let dict = ["data":dictionary]
                        
                        DispatchQueue.main.async { completion(dict, nil) }
                    }else {
                        DispatchQueue.main.async { completion(dictionary as? [String:Any], nil) }
                    }
                    
                }
                catch {
                    DispatchQueue.main.async { completion(nil, error) }
                }
            }
        })
        
        task.resume()
        
        return task
    }
    
    public func cancelAllRequests() {
        session.getAllTasks { (tasks) in
            tasks.forEach({ $0.cancel() })
        }
       
    }
    
    private func formattedRequest(url: String, method: HTTPMethod, headers: [String: String], body: Data?) -> URLRequest {
        guard let url = URL(string: url) else {
            return URLRequest(url: URL(string: "https://www.google.com")!)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body
        return request
    }
    
    private func validate(response: URLResponse?, with error: Error?, optionallyRetry request: URLRequest, authHandler: OAuth2Handler, useRefreshToken: Bool, method: HTTPMethod, url: String, body: Data?, completion: @escaping APICompletion) -> Bool {
        if !useRefreshToken {
            return true
        }
        if (error != nil) || (response == nil) || (response != nil && (response is HTTPURLResponse) && !self.acceptableStatusCodes.contains((response as! HTTPURLResponse).statusCode)) {
            
            self.activeRetriers.append(authHandler)
            authHandler.shouldRetry(request: request, response: response, completion: { (shouldRetry, delay) in
                
                if shouldRetry {
                    self.apiCallQueue.asyncAfter(deadline: .now() + delay) {
                        self.request(useRefreshToken: useRefreshToken, method: method, url: url, body: body, completion: completion)
                    }
                }
                else {
                    DispatchQueue.main.async { completion(nil, error) }
                }
                
                if let index = self.activeRetriers.firstIndex(where: { $0 === authHandler }) {
                    self.activeRetriers.remove(at: index)
                }
            })
            
            return false
        }
        
        return true
    }
    
    
    
    
    private func debugResponsePrint(url: String?, method: HTTPMethod, headers: [String:Any], body: Data?,response:URLResponse?,error:Error?,data:Data?) {
        print("\n\n\n\n")
        if let url = url {
            print("URL : ",url)
        }
        print("Http Method : ",method.rawValue)
        print("Headers : ",headers.json)
        if let b = body {
            print("Body : ",b.stringValue)
        }
        if let response = response {
            print("Response : ",response)
        }
        if let error = error {
            print("Error : ",error)
        }
        if let d = data {
            print("Response Data : ",d.stringValue)
        }
        print("\n\n\n\n")
    }
    
}




extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: String.Encoding.utf8, allowLossyConversion: false) {
            append(data)
        }
        
    }
}



// MARK:- IMAGE API
extension API {
    
    
    private func formattedRequestWithImageFormData(url: String, method: HTTPMethod, headers: [String: String],dictData : Dictionary<String,Any>,arrImageData:[[String:Any]]) -> URLRequest {
        let bodyM: NSMutableData = NSMutableData()
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method.rawValue
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        let boundry:NSString="---------------------------14737809831466499882746641449"
        let contentType:NSString=NSString(format: "multipart/form-data; boundary=%@", boundry)
        for (key, value) in headers {
            if key == "Content-Type" {
                request .setValue(contentType as String, forHTTPHeaderField: "Content-Type")
            }else{
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        for (key, value) in dictData
        {
            bodyM.appendString("--\(boundry)\r\n")
            bodyM.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            bodyM.appendString("\(value)\r\n")
        }
        
        for (index,dictImageData) in arrImageData.enumerated() {
            
            for (key,value) in dictImageData {
                
                
                if let paramValue = value as? Data {
                    bodyM.appendString("--\(boundry)\r\n")
                    bodyM.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                    bodyM.appendString("\(value)\r\n")
                    
                    bodyM.appendString(String(format:"--%@\r\n", boundry))
                    let name = String(format: "%d%d%d", Int(Date().timeIntervalSince1970),Int.randomNumberWith(digits: 4),index)
                    bodyM.appendString(String(format:"Content-Disposition: attachment; name=\"%@\"; filename=\"%d.jpeg\"\r\n",key,name))
                    bodyM.appendString(String(format:"Content-Type: application/octet-stream\r\n\r\n"))
                    
                    bodyM.append(paramValue)
                }
                /*
                else {
                    bodyM.appendString("--\(boundry)\r\n")
                    bodyM.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                    bodyM.append(String(describing: value).data(using: .utf8)!)
                }
                 */
                
                bodyM.append("\r\n".data(using: .utf8)!)
            }
            
        }
        
       
        bodyM.appendString(String(format:"--%@--\r\n",boundry))
        
        
        request.httpBody=bodyM as Data
        request.timeoutInterval = 120
        request.httpBody = bodyM as Data
        
        return request
    }
    
    // MARK: - Convenience
    @discardableResult
    public func requestWithImage(useRefreshToken: Bool = true, method: HTTPMethod, url: String,dictData : Dictionary<String,Any>,arrImageData : [[String:Any]], completion: @escaping APICompletion) -> URLSessionTask {
        
        
        let authHandler = OAuth2Handler(accessToken: self.getAuthToken(),
                                        refreshToken: self.getRefreshToken())
        authHandler.useRefreshToken = useRefreshToken
        
        let headers = self.headersImage()
        var request = self.formattedRequestWithImageFormData(url: url, method: method, headers: headers, dictData: dictData, arrImageData: arrImageData)
        
        request.timeoutInterval = 1000
        
        
        let task = self.session.dataTask(with: request, completionHandler: { (data, response, error) in
            self.debugResponsePrint(url: url, method: method, headers: headers, body: nil, response: response, error: error, data: data) // body = request.httpBody
            self.apiCallQueue.async {
                
                guard self.validateImage(response: response, with: error, optionallyRetry: request, authHandler: authHandler, useRefreshToken: useRefreshToken, method: method, url: url, dictData: dictData, arrImageData: arrImageData, completion: completion) else {
                    
                    return
                }
                do {
                    guard let data = data, error == nil else {
                        //completion(nil, error)
                        DispatchQueue.main.async { completion(nil, error) }
                        return
                    }
                    
                    let dictionary = try JSONSerialization.jsonObject(with: data)
                    if(dictionary is [[String:Any]]) {
                        let dict = ["data":dictionary]
                        DispatchQueue.main.async { completion(dict, nil) }
                    }else {
                        DispatchQueue.main.async { completion(dictionary as? [String:Any], nil) }
                    }
                }
                catch {
                    DispatchQueue.main.async { completion(nil, error) }
                }
            }
        })
        task.resume()
        return task
        
    }
    
    private func validateImage(response: URLResponse?, with error: Error?, optionallyRetry request: URLRequest, authHandler: OAuth2Handler, useRefreshToken: Bool, method: HTTPMethod, url: String, dictData : Dictionary<String,Any>,arrImageData : [[String:Any]], completion: @escaping APICompletion) -> Bool {
        if !useRefreshToken {
            return true
        }
        if (error != nil) || (response == nil) || (response != nil && (response is HTTPURLResponse) && !self.acceptableStatusCodes.contains((response as! HTTPURLResponse).statusCode)) {
            
            self.activeRetriers.append(authHandler)
            authHandler.shouldRetry(request: request, response: response, completion: { (shouldRetry, delay) in
                
                if shouldRetry {
                    self.apiCallQueue.asyncAfter(deadline: .now() + delay) {
                        self.requestWithImage(method: method, url: url, dictData: dictData, arrImageData: arrImageData, completion: completion)
                    }
                }
                else {
                    DispatchQueue.main.async { completion(nil, error) }
                }
                
                if let index = self.activeRetriers.firstIndex(where: { $0 === authHandler }) {
                    self.activeRetriers.remove(at: index)
                }
            })
            
            return false
        }
        return true
    }
    
}
