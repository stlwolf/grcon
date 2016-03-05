//
//  LoginViewController.swift
//  grcon
//
//  Created by eddy on 2016/03/05.
//  Copyright © 2016年 eddy. All rights reserved.
//

import Foundation

class LoginViewController : UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // add view
        self.view.backgroundColor = UIColor(red: 100, green: 100, blue: 100, alpha: 1.0)
    }
    
    @IBOutlet weak var loginButton: UIButton!
    @IBAction func pushChatView(sender: AnyObject) {
        // 遷移の実装は一体どれがいいのか...
        performSegueWithIdentifier("loginPush", sender: nil)
    }
}