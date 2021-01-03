//
//  Data+Helper.swift
//  API Demo
//
//  Created by Mitul Patel on 03/01/21.
//

import Foundation
import UIKit


extension Data {
    var json : [String:Any]  {
        get {
            let dictData = try? JSONSerialization.jsonObject(with: self, options: []) as? [String:Any]
            if let dict = dictData {
                return dict
            }
            return [:]
        }
        
    }
    
    var jsonDictionary : [String:Any]?  {
        get {
            let dictData = try? JSONSerialization.jsonObject(with: self, options: []) as? [String:Any]
            if let dict = dictData {
                return dict
            }
            return nil
        }
        
    }
    
    var stringValue : String {
        get {
            
            let jsonString = String(decoding: self, as: UTF8.self)
            return jsonString
            
        }
    }
    
    
}

extension Dictionary {
    
    var json : String {
        get {
            let jsonData = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            
            if let jsonData = jsonData {
                let jsonString = String(decoding: jsonData, as: UTF8.self)
                return jsonString
            }
            return ""
        }
    }
    
    var data : Data? {
        get {
            let jsonData = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            if let jsonData = jsonData {
                return jsonData
            }
            return nil
        }
    }
}


extension Int {
    
    init(_ range: Range<Int> ) {
        let delta = range.lowerBound < 0 ? abs(range.lowerBound) : 0
        let min = UInt32(range.lowerBound + delta)
        let max = UInt32(range.upperBound   + delta)
        self.init(Int(min + arc4random_uniform(max - min)) - delta)
    }
    
    static func randomNumberWith(digits:Int) -> Int {
        let min = Int(pow(Double(10), Double(digits-1))) - 1
        let max = Int(pow(Double(10), Double(digits))) - 1
        return Int(Range(uncheckedBounds: (min, max)))
    }
    
}
