//
//  MasterTableViewCell.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore
import Account
import RSTree

protocol MasterFeedTableViewCellDelegate: class {
	func disclosureSelected(_ sender: MasterFeedTableViewCell, expanding: Bool)
}

class MasterFeedTableViewCell : VibrantTableViewCell {

	weak var delegate: MasterFeedTableViewCellDelegate?

	override var accessibilityLabel: String? {
		set {}
		get {
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessiblity")
				return "\(name) \(unreadCount) \(unreadLabel)"
			} else {
				return name
			}
		}
	}

	var faviconImage: UIImage? {
		didSet {
			faviconImageView.image = faviconImage
			
			if self.traitCollection.userInterfaceStyle == .dark {
				DispatchQueue.global(qos: .background).async {
					if self.faviconImage?.isDark() ?? false {
						DispatchQueue.main.async {
							self.faviconImageView.backgroundColor = AppAssets.avatarBackgroundColor
						}
					} else {
						DispatchQueue.main.async {
							self.faviconImageView.backgroundColor = nil
						}
					}
				}
			}
			
		}
	}

	var isDisclosureAvailable = false {
		didSet {
			if isDisclosureAvailable != oldValue {
				setNeedsLayout()
			}
		}
	}
	
	var unreadCount: Int {
		get {
			return unreadCountView.unreadCount
		}
		set {
			if unreadCountView.unreadCount != newValue {
				unreadCountView.unreadCount = newValue
				unreadCountView.isHidden = (newValue < 1)
				setNeedsLayout()
			}
		}
	}

	var name: String {
		get {
			return titleView.text ?? ""
		}
		set {
			if titleView.text != newValue {
				titleView.text = newValue
				setNeedsLayout()
			}
		}
	}

	private let titleView: UILabel = {
		let label = NonIntrinsicLabel()
		label.numberOfLines = 0
		label.allowsDefaultTighteningForTruncation = false
		label.adjustsFontForContentSizeCategory = true
		label.font = .preferredFont(forTextStyle: .body)
		return label
	}()

	private let faviconImageView: UIImageView = {
		let imageView = NonIntrinsicImageView(image: AppAssets.faviconTemplateImage)
		imageView.layer.cornerRadius = MasterFeedTableViewCellLayout.faviconCornerRadius
		imageView.clipsToBounds = true
		return imageView
	}()

	private var isDisclosureExpanded = false
	private var disclosureButton: UIButton?
	private var unreadCountView = MasterFeedUnreadCountView(frame: CGRect.zero)
	private var isShowingEditControl = false
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	func setDisclosure(isExpanded: Bool, animated: Bool) {
		isDisclosureExpanded = isExpanded
		let duration = animated ? 0.3 : 0.0

		UIView.animate(withDuration: duration) {
			if self.isDisclosureExpanded {
				self.disclosureButton?.accessibilityLabel = NSLocalizedString("Collapse Folder", comment: "Collapse Folder")
				self.disclosureButton?.imageView?.transform = CGAffineTransform(rotationAngle: 1.570796)
			} else {
				self.disclosureButton?.accessibilityLabel = NSLocalizedString("Expand Folder", comment: "Expand Folder") 
				self.disclosureButton?.imageView?.transform = CGAffineTransform(rotationAngle: 0)
			}
		}
	}
	
	override func applyThemeProperties() {
		super.applyThemeProperties()
		titleView.highlightedTextColor = AppAssets.vibrantTextColor
	}

	override func setHighlighted(_ highlighted: Bool, animated: Bool) {
		super.setHighlighted(highlighted, animated: animated)
		updateVibrancy(animated: animated)
	}

	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		updateVibrancy(animated: animated)
	}
	
	override func willTransition(to state: UITableViewCell.StateMask) {
		super.willTransition(to: state)
		isShowingEditControl = state.contains(.showingEditControl)
	}
	
	override func sizeThatFits(_ size: CGSize) -> CGSize {
		let layout = MasterFeedTableViewCellLayout(cellWidth: bounds.size.width, insets: safeAreaInsets, label: titleView, unreadCountView: unreadCountView, showingEditingControl: isShowingEditControl, indent: indentationLevel == 1, shouldShowDisclosure: isDisclosureAvailable)
		return CGSize(width: bounds.width, height: layout.height)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		let layout = MasterFeedTableViewCellLayout(cellWidth: bounds.size.width, insets: safeAreaInsets, label: titleView, unreadCountView: unreadCountView, showingEditingControl: isShowingEditControl, indent: indentationLevel == 1, shouldShowDisclosure: isDisclosureAvailable)
		layoutWith(layout)
	}
	
	@objc func buttonPressed(_ sender: UIButton) {
		if isDisclosureAvailable {
			setDisclosure(isExpanded: !isDisclosureExpanded, animated: true)
			delegate?.disclosureSelected(self, expanding: isDisclosureExpanded)
		}
	}
	
}

private extension MasterFeedTableViewCell {

	func commonInit() {
		addSubviewAtInit(unreadCountView)
		addSubviewAtInit(faviconImageView)
		addSubviewAtInit(titleView)
		addDisclosureView()
	}

	func addDisclosureView() {
		disclosureButton = NonIntrinsicButton(type: .roundedRect)
		disclosureButton!.addTarget(self, action: #selector(buttonPressed(_:)), for: UIControl.Event.touchUpInside)
		disclosureButton?.setImage(AppAssets.disclosureImage, for: .normal)
		addSubviewAtInit(disclosureButton!)
	}
	
	func addSubviewAtInit(_ view: UIView) {
		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
	}

	func layoutWith(_ layout: MasterFeedTableViewCellLayout) {
		faviconImageView.setFrameIfNotEqual(layout.faviconRect)
		titleView.setFrameIfNotEqual(layout.titleRect)
		unreadCountView.setFrameIfNotEqual(layout.unreadCountRect)
		disclosureButton?.setFrameIfNotEqual(layout.disclosureButtonRect)
		disclosureButton?.isHidden = !isDisclosureAvailable
		separatorInset = layout.separatorInsets
	}

	func updateVibrancy(animated: Bool) {
		let tintColor = isHighlighted || isSelected ? AppAssets.vibrantTextColor : AppAssets.secondaryAccentColor
		let duration = animated ? 0.6 : 0.0
		UIView.animate(withDuration: duration) {
			self.disclosureButton?.tintColor  = tintColor
			self.faviconImageView.tintColor = tintColor
		}
	}
	
}
