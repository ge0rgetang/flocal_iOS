//
//  UserListTableViewCell.swift
//  flocal
//
//  Created by George Tang on 6/20/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class UserListTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var profilePicImageView: UIImageView!
    @IBOutlet weak var handleLabel: UILabel!
    
    @IBOutlet weak var infoLabel: UILabel!
    
    @IBOutlet weak var addButton: UIButton!
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
