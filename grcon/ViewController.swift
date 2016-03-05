//
//  ViewController.swift
//  concierge-gourmetput
//
//  Created by eddy on 2016/02/27.
//  Copyright © 2016年 eddy. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import APIKit
import ObjectMapper
import Firebase

// 基底プロトコル
public protocol BluemixRequestType: RequestType {
}

// bluemixアクセス基本情報
public extension BluemixRequestType {
    public var method: HTTPMethod {
        return .GET
    }
    
    public var baseURL: NSURL {
        return NSURL(string: "http://concierge-gourmet.au-syd.mybluemix.net")!
    }
}

// レスポンス用オブジェクト
public extension BluemixRequestType where Self.Response: Mappable {
    public func responseFromObject(object: AnyObject, URLResponse: NSHTTPURLResponse) -> Self.Response? {
        
        // 受信データを[String:AnyObject]のDictionary型にキャストする
        guard let dictionary = object as? [String: AnyObject] else {
            return nil
        }
        
        let mapper = Mapper<Response>()
        guard let object = mapper.map(dictionary) else {
            return nil
        }
        
        return object
    }
}

// API毎のモデル構造体
// お店データ取得API用
public struct Restaurant: Mappable {
    var restaurant_name: String!    // お店の名前
    var restaurant_url: String!     // お店のURL
    var input_text: String!         // NLCの検索条件に利用されたメッセージ
    var image_url: String!          // お店の画像用URL
    var budget: String!             // 参考値段
    var location: String!           // お店座標
    
    public init?(_ map: Map) {}
    
    public mutating func mapping(map: Map) {
        self.restaurant_name <- map["restaurant_name"]
        self.restaurant_url <- map["restaurant_url"]
        self.input_text <- map["input_text"]
        self.image_url <- map["image_url"]
        self.budget <- map["budget"]
        self.location <- map["location"]
    }
}

// リクエストAPIオブジェクト
public struct NfcRequest: BluemixRequestType {
    
    // レストラン情報を取得するAPI
    public typealias Response = Restaurant
    let send_message: String
    
    public init(message: String) {
        self.send_message = message
    }
    
    // メソッドはPOST
    public var method: HTTPMethod {
        return .POST
    }
    
    // フォームにしないとダメ
    public var requestBodyBuilder: RequestBodyBuilder {
        return .URL(encoding: NSUTF8StringEncoding)
    }
    
    // BASE_URL以降のAPIパス
    public var path: String {
        return "/api/nfc"
    }
    
    // 送信する質問データ
    public var parameters: [String: AnyObject] {
        return ["data": self.send_message]
    }
}

class ViewController: JSQMessagesViewController {

    var fb_server: Firebase!
    let MAX_MESSAGE_NUM: UInt = 10
    let FIREBASE_URL: String = "https://resplendent-heat-414.firebaseio.com/"
    let FIREBASE_ROOM_ID: String = "messages"
    
    // 表示メッセージリスト
    var messages: [JSQMessage]?
    
    // JSQUserリスト
    var jsqUsers: [JSQUser]?
    
    // 暫定キーボード隠す関数
    func DismissKeyboard() {
        view.endEditing(true)
    }
    
    // firebaseの初期化
    func setupFirebase() {
        
        // firebaseへのアクセス用
        self.fb_server = Firebase(url: self.FIREBASE_URL + self.FIREBASE_ROOM_ID + "/")
        
        // 最新10件をFirebaseから取得する
        // 最新のデータが追加されるたびに、再取得を行う
        self.fb_server.queryLimitedToLast(self.MAX_MESSAGE_NUM).observeEventType(FEventType.ChildAdded, withBlock: { (snapshot) in
            print(snapshot.value!)
            
            let text = snapshot.value["text"] as? String
            let sender = snapshot.value["sender"] as? String
            let name = snapshot.value["name"] as? String
            let type = snapshot.value["type"] as? String
            
            let message = self.makeJSQMessage(sender, name: name, type: type!, value: text)
            
            self.messages?.append(message)
            self.finishSendingMessageAnimated(true)
        })
    }
    
    // firebaseへのテキスト送信
    func sendFirebase(senderId: String, name: String, type: String="text", text: String) {
        
        let post = ["sender": senderId, "name": name, "type": type, "text": text]
        let postRef = self.fb_server.childByAutoId()
        
        postRef.setValue(post)
    }

    // 簡易クラス
    class JSQUser {
        var senderId: String?
        var displayName: String?
        var bubble: JSQMessagesBubbleImage!
        var avatar: JSQMessagesAvatarImage!
        
        init(senderId sender:String, displayName name:String, userType type: String="user") {
            self.senderId = sender
            self.displayName = name
            
            // 吹き出し情報の設定
            let bubbleFactory = JSQMessagesBubbleImageFactory()
            switch type {
            // コンシェルジュ
            case "grcon":
                self.bubble = bubbleFactory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleBlueColor())
            // 他ユーザ
            case "friend":
                self.bubble = bubbleFactory.incomingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleLightGrayColor())
            // 使用者ユーザ
            default:
                self.bubble = bubbleFactory.outgoingMessagesBubbleImageWithColor(UIColor.jsq_messageBubbleGreenColor())
            }
            
            // アバター情報設定
            self.avatar = self.createAvatarImage(fileName: type)
        }
        
        // avater情報作成 -> 今はローカルからのみ作成する
        func createAvatarImage(fileName name: String, getType type: String="local") -> JSQMessagesAvatarImage? {
            var avatar: JSQMessagesAvatarImage
            switch type {
            default:
                avatar = JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: name), diameter: 64)
            }
            return avatar
        }
    }
    
    // JSQMessageユーザ初期化
    func setupJSQUser() {
        
        // 自分
        self.senderId = "user"
        self.senderDisplayName = "eddy"
        
        // JSQユーザ作成
        self.jsqUsers = []
        self.jsqUsers?.append(JSQUser(senderId: self.senderId, displayName: self.senderDisplayName))         // 使用者
        self.jsqUsers?.append(JSQUser(senderId: "grcon", displayName: "コンシェルジュ", userType: "grcon")) // コンシェルジュ
        
        self.messages = []
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // キーボード消したい
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: "DismissKeyboard")
        view.addGestureRecognizer(tap)
        
        // JSQMessageView初期化
        inputToolbar!.contentView!.leftBarButtonItem = nil
        automaticallyScrollsToMostRecentMessage = true
        
        self.setupJSQUser()
        self.setupFirebase()
    }

    // バルーンをタッチした時に呼ばれるイベント
    override func collectionView(collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAtIndexPath indexPath: NSIndexPath!) {
        let tapbubble = self.messages![indexPath.item]
        print(tapbubble)
        
        // バルーンはmediaデータ
        if let _ = tapbubble.media {
            let detailViewController: UIViewController = DetailView()
            self.navigationController?.pushViewController(detailViewController, animated: true)
            return
        }
        
        // バルーンはtextデータ
        if let _ = tapbubble.text {
        }
    }
    
    // アプリ内メッセージ作成部分を取り出してみた
    func makeJSQMessage(sender: String!, name: String!, type: String, value: String!) -> JSQMessage {
        var message: JSQMessage
        switch type {
        case "text":
            message = JSQMessage(senderId: sender, displayName: name, text: value)
        case "media":
            message = JSQMessage(senderId: sender, displayName: name, media: self.createPhotoItem(value, isOutgoing: false))
        default:
            message = JSQMessage(senderId: sender, displayName: name, text: value)
        }
        return message
    }
    
    // sendボタンを押した時
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
        
        print("senderId:" + senderId! + ", displayName:" + senderDisplayName + ", text:" + text!)
        
        // ユーザメッセージをfbに送信
        self.sendFirebase(senderId, name: senderDisplayName, text: text)
        
        // FIXME:サーバーにメッセージを送信する
        var nfc_answer: String = ""
        
        let request = NfcRequest(message: text)
        Session.sendRequest(request) { result in
            switch result {
            case .Success(let response):
                
                print(response)
                nfc_answer = "こちらがオススメです。" + response.restaurant_name + " " + response.restaurant_url
                
                // FIXME:かっこわるすぎなので設計見直す
                let grcon:JSQUser? = self.jsqUsers?.filter { $0.senderId == "grcon" }[0]
                print(grcon)

                // お店の画像メッセージをfbに送信
                self.sendFirebase(grcon!.senderId!,  name: grcon!.displayName!, type: "media", text: response.image_url)
                
                // オススメメッセージをfbに送信
                self.sendFirebase(grcon!.senderId!, name: grcon!.displayName!, text: nfc_answer)
                
            case .Failure(let error):
                print("error: \(error)")
            }
        }
        
        // メッセージの送信処理を完了する（画面上にメッセージが表示される）
        self.finishReceivingMessageAnimated(true)
        self.finishSendingMessageAnimated(true)
    }
    
    // アイテムごとに参照するメッセージデータを返す
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
        return self.messages?[indexPath.item]
    }
        
    // アイテム毎のMessageBubble(背景)を返す
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        let sender = self.messages?[indexPath.item].senderId
        var bubbleImage: JSQMessageBubbleImageDataSource! = nil
        
        // 該当ユーザ探す
        for user in self.jsqUsers! {
            if sender == user.senderId {
                bubbleImage = user.bubble!
                break
            }
        }
        return bubbleImage
    }
    
    // アイテム毎にアバター画像を返す
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        let sender = self.messages?[indexPath.item].senderId
        var avatarImage: JSQMessageAvatarImageDataSource! = nil
        
        // 該当ユーザ探す
        for user in self.jsqUsers! {
            if sender == user.senderId {
                avatarImage = user.avatar!
                break
            }
        }
        return avatarImage
    }
    
    // アイテムの総数を返す
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (self.messages?.count)!
    }
    
    // webから画像もってくる
    private func createImage(url: String) -> UIImage {
        let failimage: UIImage! = UIImage(named: "noimage")
        guard let nsurl = NSURL(string: url) else {
            return failimage
        }
        guard let data = NSData(contentsOfURL: nsurl) else {
            return failimage
        }
        guard let image = UIImage(data: data) else {
            return failimage
        }
        return image
    }
    
    // 画像遅延ロード
    private func createPhotoItem(url: String, isOutgoing: Bool) -> JSQPhotoMediaItem {
        let photoItem = JSQPhotoMediaItem()
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            photoItem.image = self.createImage(url)
            dispatch_async(dispatch_get_main_queue(), {
                // 2. photoItem.imageにネットワークから読み込んだ画像を設定
                self.collectionView?.reloadData()
            })
        })
        photoItem.appliesMediaViewMaskAsOutgoing = isOutgoing
        // 1. この時点ではphotoItem.image=nilなのでローディング表示
        return photoItem
    }
    
    // メモリ不足ワーニング？
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}