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
    
    // JSQMessageオブジェクトのsenderIdに入れる。一旦これがユニークID
    @IBOutlet weak var userName: UITextField!
    
    // ログインボタン
    @IBOutlet weak var loginButton: UIButton!
    @IBAction func pushChatView(sender: AnyObject) {
        // 遷移の実装は一体どれがいいのか...
        performSegueWithIdentifier("loginPush", sender: nil)
    }
    
    // 遷移前の初期化
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let chatViewController = segue.destinationViewController as! ChatViewController
        // ユーザID
        chatViewController.senderId = self.userName!.text
    }
}