//
//  DetailWebViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import WebKit
import RSWeb
import Articles

protocol DetailWebViewControllerDelegate: class {
	func mouseDidEnter(_: DetailWebViewController, link: String)
	func mouseDidExit(_: DetailWebViewController, link: String)
}

final class DetailWebViewController: NSViewController, WKUIDelegate {

	weak var delegate: DetailWebViewControllerDelegate?
	var webView: DetailWebView!
	var state: DetailState = .noSelection {
		didSet {
			if state != oldValue {
				reloadHTML()
			}
		}
	}

	#if !MAC_APP_STORE
		private var webInspectorEnabled: Bool {
			get {
				return webView.configuration.preferences._developerExtrasEnabled
			}
			set {
				webView.configuration.preferences._developerExtrasEnabled = newValue
			}
		}
	#endif
	
	private var waitingForFirstReload = false
	private let keyboardDelegate = DetailKeyboardDelegate()
	private var readingPositionIndicatorView: NSView!
	private var readingPositionIndicatorOffsetY: CGFloat = 0.0
	private var readingPositionIndicatorViewTopAnchorConstraint: NSLayoutConstraint?

	private struct MessageName {
		static let mouseDidEnter = "mouseDidEnter"
		static let mouseDidExit = "mouseDidExit"
	}

	override func loadView() {
		// Wrap the webview in a box configured with the same background color that the web view uses
		let box = NSBox(frame: .zero)
		box.boxType = .custom
		box.borderType = .noBorder
		box.titlePosition = .noTitle
		box.contentViewMargins = .zero
		box.fillColor = NSColor(named: "webviewBackgroundColor")!

		view = box
		
		let preferences = WKPreferences()
		preferences.minimumFontSize = 12.0
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.javaScriptEnabled = true

		let configuration = WKWebViewConfiguration()
		configuration.preferences = preferences

		let userContentController = WKUserContentController()
		userContentController.add(self, name: MessageName.mouseDidEnter)
		userContentController.add(self, name: MessageName.mouseDidExit)
		configuration.userContentController = userContentController

		webView = DetailWebView(frame: NSRect.zero, configuration: configuration)
		webView.uiDelegate = self
		webView.navigationDelegate = self
		webView.keyboardDelegate = keyboardDelegate
		webView.translatesAutoresizingMaskIntoConstraints = false
		if let userAgent = UserAgent.fromInfoPlist() {
			webView.customUserAgent = userAgent
		}

		box.addSubview(webView)

		readingPositionIndicatorView = NSView(frame: NSRect.zero)
		readingPositionIndicatorView.wantsLayer = true
		readingPositionIndicatorView.layer?.backgroundColor = NSColor.systemYellow.cgColor
		readingPositionIndicatorView.translatesAutoresizingMaskIntoConstraints = false
		readingPositionIndicatorView.isHidden = true

		box.addSubview(readingPositionIndicatorView)

		readingPositionIndicatorViewTopAnchorConstraint = NSLayoutConstraint(item: readingPositionIndicatorView!, attribute: NSLayoutConstraint.Attribute.top, relatedBy: NSLayoutConstraint.Relation.equal, toItem: view, attribute: NSLayoutConstraint.Attribute.top, multiplier: 1.0, constant: 0.0)

		let constraints = [
			webView.topAnchor.constraint(equalTo: view.topAnchor),
			webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			readingPositionIndicatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			readingPositionIndicatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			readingPositionIndicatorView.heightAnchor.constraint(equalToConstant: 20.0),
			readingPositionIndicatorViewTopAnchorConstraint!
		]

		NSLayoutConstraint.activate(constraints)

		// Hide the web view until the first reload (navigation) is complete (plus some delay) to avoid the awful white flash that happens on the initial display in dark mode.
		// See bug #901.
		webView.isHidden = true
		waitingForFirstReload = true

		#if !MAC_APP_STORE
			webInspectorEnabled = AppDefaults.webInspectorEnabled

			NotificationCenter.default.addObserver(self, selector: #selector(webInspectorEnabledDidChange(_:)), name: .WebInspectorEnabledDidChange, object: nil)
		#endif

		webView.loadHTMLString(ArticleRenderer.page.html, baseURL: ArticleRenderer.page.baseURL)
		
	}

	// MARK: Scrolling

	func canScrollDown(_ callback: @escaping (Bool) -> Void) {
		fetchScrollInfo { (scrollInfo) in
			callback(scrollInfo?.canScrollDown ?? false)
		}
	}

	override func scrollPageDown(_ sender: Any?) {
		webView.scrollPageDown(sender)
		if(readingPositionIndicatorOffsetY > 0.0) {
			readingPositionIndicatorViewTopAnchorConstraint?.constant = readingPositionIndicatorOffsetY
			self.readingPositionIndicatorView.alphaValue = 0.6
			readingPositionIndicatorView.isHidden = false

			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
				NSAnimationContext.runAnimationGroup({ (NSAnimationContext) in
					NSAnimationContext.duration = 1.5
					self.readingPositionIndicatorView.animator().alphaValue = 0.0
				}) {
					self.readingPositionIndicatorView.isHidden = true
				}
			}
		}
	}
}

// MARK: - WKScriptMessageHandler

extension DetailWebViewController: WKScriptMessageHandler {

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		if message.name == MessageName.mouseDidEnter, let link = message.body as? String {
			delegate?.mouseDidEnter(self, link: link)
		}
		else if message.name == MessageName.mouseDidExit, let link = message.body as? String{
			delegate?.mouseDidExit(self, link: link)
		}
	}
}

// MARK: - WKNavigationDelegate

extension DetailWebViewController: WKNavigationDelegate {

	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		if navigationAction.navigationType == .linkActivated {
			if let url = navigationAction.request.url {
				Browser.open(url.absoluteString)
			}
			decisionHandler(.cancel)
			return
		}

		decisionHandler(.allow)
	}
	
	public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// See note in viewDidLoad()
		if waitingForFirstReload {
			assert(webView.isHidden)
			waitingForFirstReload = false
			reloadHTML()

			// Waiting for the first navigation to complete isn't long enough to avoid the flash of white.
			// A hard coded value is awful, but 5/100th of a second seems to be enough.
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
				webView.isHidden = false
			}
		}
	}
}

// MARK: - Private
struct TemplateData: Codable {
	let style: String
	let body: String
}

private extension DetailWebViewController {

	func reloadHTML() {
		let style = ArticleStylesManager.shared.currentStyle
		let rendering: ArticleRenderer.Rendering

		switch state {
		case .noSelection:
			rendering = ArticleRenderer.noSelectionHTML(style: style)
		case .multipleSelection:
			rendering = ArticleRenderer.multipleSelectionHTML(style: style)
		case .loading:
			rendering = ArticleRenderer.loadingHTML(style: style)
		case .article(let article):
			rendering = ArticleRenderer.articleHTML(article: article, style: style)
		case .extracted(let article, let extractedArticle):
			rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, style: style)
		}
		
		let templateData = TemplateData(style: rendering.style, body: rendering.html)
		
		let encoder = JSONEncoder()
		var render = "error();"
		if let data = try? encoder.encode(templateData) {
			let json = String(data: data, encoding: .utf8)!
			render = "render(\(json));"
		}

		webView.evaluateJavaScript(render)
	}

	func fetchScrollInfo(_ callback: @escaping (ScrollInfo?) -> Void) {
		var javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: document.body.scrollTop}; x"
		if #available(macOS 10.15, *) {
			javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: window.pageYOffset}; x"
		}

		webView.evaluateJavaScript(javascriptString) { (info, error) in
			guard let info = info as? [String: Any] else {
				callback(nil)
				return
			}
			guard let contentHeight = info["contentHeight"] as? CGFloat, let offsetY = info["offsetY"] as? CGFloat else {
				callback(nil)
				return
			}

			let scrollInfo = ScrollInfo(contentHeight: contentHeight, viewHeight: self.webView.frame.height, offsetY: offsetY)
			self.readingPositionIndicatorOffsetY = scrollInfo.canScrollDownFullPage() ? 0.0 : scrollInfo.readingIndicatorYPosition()
			callback(scrollInfo)
		}
	}

	#if !MAC_APP_STORE
		@objc func webInspectorEnabledDidChange(_ notification: Notification) {
			self.webInspectorEnabled = notification.object! as! Bool
		}
	#endif
}

// MARK: - ScrollInfo

private struct ScrollInfo {

	let contentHeight: CGFloat
	let viewHeight: CGFloat
	let offsetY: CGFloat
	let canScrollDown: Bool
	let canScrollUp: Bool

	init(contentHeight: CGFloat, viewHeight: CGFloat, offsetY: CGFloat) {
		self.contentHeight = contentHeight
		self.viewHeight = viewHeight
		self.offsetY = offsetY

		self.canScrollDown = viewHeight + offsetY < contentHeight
		self.canScrollUp = offsetY > 0.1
	}

	public func isLastPage() -> Bool {
		offsetY + viewHeight >= contentHeight
	}

	public func canScrollDownFullPage() -> Bool {
		offsetY + (2 * viewHeight) < contentHeight
	}

	public func scrollDownRemaining() -> CGFloat {
		contentHeight - offsetY - viewHeight
	}

	public func readingIndicatorYPosition() -> CGFloat {
		viewHeight - scrollDownRemaining()
	}
}
