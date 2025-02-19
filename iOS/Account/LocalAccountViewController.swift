//
//  LocalAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/19/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account

class LocalAccountViewController: UITableViewController {

	@IBOutlet weak var nameTextField: UITextField!
	
	weak var delegate: AddAccountDismissDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.title = Account.defaultLocalAccountName
		nameTextField.delegate = self
	}

	@IBAction func cancel(_ sender: Any) {
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
	@IBAction func add(_ sender: Any) {
		let account = AccountManager.shared.createAccount(type: .onMyMac)
		account.name = nameTextField.text
		dismiss(animated: true, completion: nil)
		delegate?.dismiss()
	}
	
}

extension LocalAccountViewController: UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
	
}
