//
//  PostTableViewCell.swift
//  flocal
//
//  Created by George Tang on 6/19/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class PostTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var profilePicImageView: UIImageView!
    @IBOutlet weak var handleLabel: UILabel!
    
    @IBOutlet weak var textView: UITextView!
    
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var replyLabel: UILabel!
    
    @IBOutlet weak var upvoteButton: UIButton!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var downvoteButton: UIButton!
    
    @IBOutlet weak var imagePicAspectTall: NSLayoutConstraint!
    @IBOutlet weak var imagePicAspectSquare: NSLayoutConstraint!
    @IBOutlet weak var imagePicAspectWide: NSLayoutConstraint!
    @IBOutlet weak var imagePicImageView: UIImageView!
    @IBOutlet weak var playImageView: UIImageView!
        
    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.textView.textContainerInset = UIEdgeInsets.zero
        self.textView.textContainer.lineFragmentPadding = 0
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
