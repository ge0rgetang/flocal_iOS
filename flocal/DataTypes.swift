//
//  DataTypes.swift
//  flocal
//
//  Created by George Tang on 9/19/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import Foundation

struct Post {
    var postID: String = "0"
    var userID: String = "0"
    var type: String = "error"
    var handle: String = "error"
    var points: Int = 0
    var score: Double = 0
    var voteStatus: String = "none"
    var content: String = "error"
    var timestamp: String = "error"
    var timestampUTC: String = "error"
    var replyString: String = "- replies"
    var originalReverseTimestamp: TimeInterval = 0
    var profilePicURL: URL?
    var postPicURL: URL?
    var postVidURL: URL?
    var postVidPreviewURL: URL?
}

struct Reply {
    var replyID: String = "0"
    var userID: String = "0"
    var profilePicURL: URL?
    var handle: String = "error"
    var points: Int = 0
    var score: Double = 0
    var voteStatus: String = "none"
    var content: String = "error"
    var timestamp: String = "error"
    var originalReverseTimestamp: TimeInterval = 0
}

struct User {
    var userID: String = "0"
    var handle: String = "error"
    var profilePicURL: URL?
    var points: Int = 0
    var followersCount: Int = 0
    var description: String = "error"
    var originalReverseTimestamp: TimeInterval = 0
    var didIAdd: Bool = false 
}

struct Chat {
    var chatID: String = "0"
    var messageID: String = "0"
    var userID: String = "0"
    var profilePicURL: URL?
    var handle: String = "error"
    var type: String = "error"
    var timestamp: String = "error"
    var originalReverseTimestamp: TimeInterval = 0
    var originalTimestamp: TimeInterval = 0
    var message: String = "error"
    var chatPicURL: URL?
    var chatVidURL: URL?
    var chatVidPreviewURL: URL?
}

struct NotificationStruct {
    var notificationID: String = "0"
    var type: String = "error"
    var postID: String = "0"
    var userID: String = "0"
    var handle: String = "error"
    var timestamp: String = "error"
    var originalReverseTimestamp: TimeInterval = 0
    var message: String = "error"
}
