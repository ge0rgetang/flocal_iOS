//
//  NotificationTableViewCell.swift
//  flocal
//
//  Created by George Tang on 6/8/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class NotificationTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var notificationImageView: UIImageView!
    @IBOutlet weak var notificationLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
