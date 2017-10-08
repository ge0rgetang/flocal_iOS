//
//  NoContentTableViewCell.swift
//  flocal
//
//  Created by George Tang on 6/23/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class NoContentTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var noContentLabel: UILabel!
    
    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
