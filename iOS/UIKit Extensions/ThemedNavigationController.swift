//
//  ThemedNavigationController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/22/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ThemedNavigationController: UINavigationController {
	
	static func template() -> UINavigationController {
		let navController = ThemedNavigationController()
		navController.configure()
		return navController
	}
	
	static func template(rootViewController: UIViewController) -> UINavigationController {
		let navController = ThemedNavigationController(rootViewController: rootViewController)
		navController.configure()
		return navController
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
			configure()
		}
	}
		
	private func configure() {
		isToolbarHidden = false
		
		if traitCollection.userInterfaceStyle == .dark {
			navigationBar.standardAppearance = UINavigationBarAppearance()
			navigationBar.tintColor = AppAssets.primaryAccentColor
			toolbar.standardAppearance = UIToolbarAppearance()
			toolbar.compactAppearance = UIToolbarAppearance()
			toolbar.tintColor = AppAssets.primaryAccentColor
		} else {
			let navigationAppearance = UINavigationBarAppearance()
			navigationAppearance.backgroundColor = AppAssets.barBackgroundColor
			navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
			navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
			navigationBar.standardAppearance = navigationAppearance
			navigationBar.tintColor = AppAssets.primaryAccentColor
			
			let toolbarAppearance = UIToolbarAppearance()
			toolbarAppearance.backgroundColor = UIColor.white
			toolbar.standardAppearance = toolbarAppearance
			toolbar.compactAppearance = toolbarAppearance
			toolbar.tintColor = AppAssets.primaryAccentColor
		}
		
	}
	
}
