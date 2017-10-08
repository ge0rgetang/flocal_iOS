//
//  TermsViewController.swift
//  flocal
//
//  Created by George Tang on 5/26/17.
//  Copyright © 2017 Dotnative, Inc. All rights reserved.
//

import UIKit
import FirebaseAnalytics    

class TermsViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var termsLabel: UILabel!
    
    // MARK: - Vars
    
    var myID: String = "0"
    let misc = Misc()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        self.preferredContentSize = CGSize(width: 320, height: 320)
        self.termsLabel.text = self.termsText
        self.myID = misc.setMyID()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppUtility.lockOrientation(.portrait)
        self.logViewTerms()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        AppUtility.lockOrientation(.all)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Analytics
    
    func logViewTerms() {
        Analytics.logEvent("viewTerms_iOS", parameters: [
            "myID": self.myID as NSObject
            ])
    }
    
    // MARK: - Terms Text
    
    var termsText =
        "flocal App End User License Agreement" + "\r\n\n" +
            
            "This End User License Agreement (“Agreement”) is between you and DotNative, Inc. and governs use of this app made available through the Apple App Store. By installing the flocal App, you agree to be bound by this Agreement and understand that there is no tolerance for objectionable content. If you do not agree with the terms and conditions of this Agreement, you are not entitled to use the flocal App." + "\r\n\n" +
            
            "In order to ensure DotNative, Inc. provides the best experience possible for everyone, we strongly enforce a no tolerance policy for objectionable content. If you see inappropriate content, please use the “Report” feature found under each post." + "\r\n\n" +
            
            "1. Parties" + "\r\n" +
            "This Agreement is between you and DotNative, Inc. only, and not Apple, Inc. (“Apple”). Notwithstanding the foregoing, you acknowledge that Apple and its subsidiaries are third party beneficiaries of this Agreement and Apple has the right to enforce this Agreement against you. DotNative, Inc., not Apple, is solely responsible for the flocal app and its content." + "\r\n\n" +
            
            "2. Privacy" + "\r\n" +
            "DotNative, Inc. may collect and use information about your usage of the flocal App, including certain types of information from and about your device. DotNative, Inc. may use this information, as long as it is in a form that does not personally identify you, to measure the use and performance of the flocal App." + "\r\n\n" +
            
            "3. Limited License" + "\r\n" +
            "DotNative, Inc. grants you a limited, non-exclusive, non-transferable, revocable license to use the flocal App for your personal, non-commercial purposes. You may only use the flocal App on Apple devices that you own or control and as permitted by the App Store Terms of Service." + "\r\n\n" +
            
            "4. Age Restrictions" + "\r\n" +
            "By using the flocal App, you represent and warrant that (a) you are 17 years of age or older and you agree to be bound by this Agreement; (b) if you are under 17 years of age, you have obtained verifiable consent from a parent or legal guardian; and (c) your use of the flocal App does not violate any applicable law or regulation. Your access to the flocal App may be terminated without warning if DotNative, Inc. believes, in its sole discretion, that you are under the age of 17 years and have not obtained verifiable consent from a parent or legal guardian. If you are a parent or legal guardian and you provide your consent to your child’s use of the flocal App, you agree to be bound by this Agreement in respect to your child’s use of the flocal App." + "\r\n\n" +
            
            "5. Objectionable Content Policy" + "\r\n" +
            "Content may not be submitted to DotNative, Inc., who will moderate all content and ultimately decide whether or not to post a submission to the extent such content includes, is in conjunction with, or alongside any, Objectionable Content. Objectionable Content includes, but is not limited to: (i) sexually explicit materials; (ii) obscene, defamatory, libelous, slanderous, violent and/or unlawful content or profanity; (iii) content that infringes upon the rights of any third party, including copyright, trademark, privacy, publicity or other personal or proprietary right, or that is deceptive or fraudulent; (iv) content that promotes the use or sale of illegal or regulated substances, tobacco products, ammunition and/or firearms; and (v) gambling, including without limitation, any online casino, sports books, bingo or poker." + "\r\n\n" +
            
            "6. Warranty" + "\r\n" +
            "DotNative, Inc. disclaims all warranties about the flocal App to the fullest extent permitted by law. To the extent any warranty exists under law that cannot be disclaimed, DotNative, Inc., not Apple, shall be solely responsible for such warranty." + "\r\n\n" +
            
            "7. Maintenance and Support" + "\r\n" +
            "DotNative, Inc. does provide minimal maintenance or support for it but not to the extent that any maintenance or support is required by applicable law, DotNative, Inc., not Apple, shall be obligated to furnish any such maintenance or support." + "\r\n\n" +
            
            "8. Product Claims" + "\r\n" +
            "DotNative, Inc., not Apple, is responsible for addressing any claims by you relating to the flocal App or use of it, including, but not limited to: (i) any product liability claim; (ii) any claim that the flocal App fails to conform to any applicable legal or regulatory requirement; and (iii) any claim arising under consumer protection or similar legislation. Nothing in this Agreement shall be deemed an admission that you may have such claims." + "\r\n\n" +
            
            "9. Third Party Intellectual Property Claims" + "\r\n" +
            "DotNative, Inc. shall not be obligated to indemnify or defend you with respect to any third party claim arising out or relating to the flocal App. To the extent DotNative, Inc. is required to provide indemnification by applicable law, DotNative, Inc., not Apple, shall be solely responsible for the investigation, defense, settlement and discharge of any claim that the flocal App or your use of it infringes any third party intellectual property right."

}
