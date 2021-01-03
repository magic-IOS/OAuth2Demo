import UIKit
public class OAuth2Handler {
    private typealias RefreshCompletion = (_ succeeded: Bool, _ accessToken: String?, _ refreshToken: String?) -> Void

    private let lock = NSLock()
    
    private var accessToken: String
    private var refreshToken: String

    private var isRefreshing = false
    
    public var useRefreshToken: Bool = true
    public var retryBlocks: [APIRetryBlock] = []
    
    
    // MARK: - Initialization
    public init(accessToken: String, refreshToken: String) {
        
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    
    
    // MARK: - APIRetrier Methods
    public func shouldRetry(request: URLRequest, response: URLResponse?, completion: @escaping APIRetryBlock) {
        lock.lock()
        defer { lock.unlock() }
        
        if let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 401 {
            retryBlocks.append(completion)
            if !isRefreshing {
                self.refreshTokens(completion: { [weak self] succeeded, accessToken, refreshToken in
                    guard let strongSelf = self else { return }
                    
                    strongSelf.lock.lock()
                    defer { strongSelf.lock.unlock() }
                    
                    if let accessToken = accessToken, let refreshToken = refreshToken {
                        strongSelf.accessToken = accessToken
                        strongSelf.refreshToken = refreshToken
                    }
                    
                    strongSelf.retryBlocks.forEach { $0(succeeded, 0.0) }
                    strongSelf.retryBlocks.removeAll()
                })
            }
        }else {
            completion(false, 0.0)
        }
    }
    
    
    // MARK: - Private - Refresh Tokens
    private func refreshTokens(completion: @escaping RefreshCompletion) {
        guard !isRefreshing else { return }
        isRefreshing = true
        
     
        var dictParam : [String:Any] = [String:Any]()
        
        dictParam["refresh_token"] = API.shared.getRefreshToken()
        
        let urlString = "" //CONSTANT_URL.SERVICE_URL + ""
        let headers = API.shared.headers()
        let data = API.shared.body(dictParam: dictParam)
        API.shared.unqualifiedRequest(url: urlString, method: .post, headers: headers, body: data, completion: { [weak self] (response, error) in
            
            guard let strongSelf = self, let response = response  else {
                completion(false,nil,nil)
                return
                
            }
           // debugPrint(response)
//            guard let resp[]
            
//            if(response["success"] as? String == "1"){
            let dictData = response
            let strAuthToken = dictData["access_token"] as? String ?? ""
            let strRefreshToken = dictData["refresh_token"] as? String ?? ""
            UserDefaults.standard.setValue(strAuthToken, forKey: "access_token")
            UserDefaults.standard.setValue(strRefreshToken, forKey: "refresh_token")
            
            UserDefaults.standard.synchronize()
            completion(true,strAuthToken,nil)
//            }else{
            
//            }
            strongSelf.isRefreshing = false
        })
    }
}
