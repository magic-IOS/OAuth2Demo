//
//  ViewController.swift
//  API Demo
//
//  Created by Mitul Patel on 02/01/21.
//

import UIKit

//   https://github.com/magic-IOS/Multiple-Image-Upload-WITH-PHP.git
class ViewController: UIViewController {

    // MARK:- UIView Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("test")
        if let img = UIImage(named: "icn_copy_success"),let data = img.jpegData(compressionQuality: 1) {

            var dictParam : [String:Any] = [:]
            dictParam["Image[]"] = data
            let arr : [[String:Any]] = [dictParam,dictParam,dictParam]
            API.shared.requestWithImage(useRefreshToken: false, method: .post, url: "http://localhost:8000/addPictureSubmit.php", dictData: [:], arrImageData: arr) { (dict, error) in
                
            }
            
        }
    }


}

