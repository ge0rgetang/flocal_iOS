//
//  FollowersTableViewCell.swift
//  flocal
//
//  Created by George Tang on 10/8/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class FollowersTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var followersLabel: UILabel!
    
    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
