//
//  WritePostTableViewCell.swift
//  flocal
//
//  Created by George Tang on 6/19/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit

class WritePostTableViewCell: UITableViewCell {
    
    // MARK: - Outlets
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
        
    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
