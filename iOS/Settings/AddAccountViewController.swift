//
//  AddAccountViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Account
import UIKit

protocol AddAccountDismissDelegate: UIViewController {
	func dismiss()
}

class AddAccountViewController: UITableViewController, AddAccountDismissDelegate {

	@IBOutlet private weak var localAccountImageView: UIImageView!
	@IBOutlet private weak var localAccountNameLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		localAccountImageView.image = AppAssets.image(for: .onMyMac)
		localAccountNameLabel.text = Account.defaultLocalAccountName
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch indexPath.row {
		case 0:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "AddLocalAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! LocalAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		case 1:
			let navController = UIStoryboard.account.instantiateViewController(withIdentifier: "FeedbinAccountNavigationViewController") as! UINavigationController
			navController.modalPresentationStyle = .currentContext
			let addViewController = navController.topViewController as! FeedbinAccountViewController
			addViewController.delegate = self
			present(navController, animated: true)
		default:
			break
		}
	}
	
	func dismiss() {
		navigationController?.popViewController(animated: false)
	}
	
}
