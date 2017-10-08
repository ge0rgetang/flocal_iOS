//
//  UserInfoTableViewCell.swift
//  flocal
//
//  Created by George Tang on 6/21/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class UserInfoTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var backgroundPicImageView: UIImageView!
    @IBOutlet weak var profilePicImageView: UIImageView!
    @IBOutlet weak var profilePicHeight: NSLayoutConstraint!
    @IBOutlet weak var profilePicTopOffsetFromBackground: NSLayoutConstraint!
    @IBOutlet weak var handleTopOffset: NSLayoutConstraint!
    @IBOutlet weak var handleLabel: UILabel!
    @IBOutlet weak var followersLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
