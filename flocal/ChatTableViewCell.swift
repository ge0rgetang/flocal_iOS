//
//  ChatTableViewCell.swift
//  flocal
//
//  Created by George Tang on 6/21/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class ChatTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var profilePicImageView: UIImageView!
    @IBOutlet weak var backView: UIView!
    @IBOutlet weak var chatLabel: UILabel!
    @IBOutlet weak var timestampLabel: UILabel!
    @IBOutlet weak var timestampLabelHeight: NSLayoutConstraint!
    
    @IBOutlet weak var imagePicAspectTall: NSLayoutConstraint!
    @IBOutlet weak var imagePicAspectSquare: NSLayoutConstraint!
    @IBOutlet weak var imagePicAspectWide: NSLayoutConstraint!
    @IBOutlet weak var imagePicImageView: UIImageView!
    @IBOutlet weak var playImageView: UIImageView!

    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
