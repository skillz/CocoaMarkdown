//
//  ViewController.swift
//  Example-iOS
//
//  Created by Indragie on 1/15/15.
//  Copyright (c) 2015 Indragie Karunaratne. All rights reserved.
//

import UIKit
import CocoaMarkdown

class ViewController: UIViewController, UITextViewDelegate {
    @IBOutlet var textView: UITextView!

    var renderer: CMAttributedStringRenderer?
    override func viewDidLoad() {
        super.viewDidLoad()
        let path = NSBundle.mainBundle().pathForResource("test", ofType: "md")!
        let document = CMDocument(contentsOfFile: path, options: CMDocumentOptions(rawValue: 0))
        renderer = CMAttributedStringRenderer(document: document, attributes: CMTextAttributes())
        renderer!.registerCustomURLSchemes(["howdyhub"])
        renderer!.registerHTMLElementTransformer(CMHTMLStrikethroughTransformer())
        renderer!.registerHTMLElementTransformer(CMHTMLSuperscriptTransformer())
        renderer!.registerHTMLElementTransformer(CMHTMLUnderlineTransformer())
        renderer!.renderAndSyncWithTextView(textView)
        textView.editable = false
        textView.selectable = true
        textView.delegate = self
    }

    func textView(textView: UITextView, shouldInteractWithTextAttachment textAttachment: NSTextAttachment, inRange characterRange: NSRange) -> Bool {
        if let textAttachment = textAttachment as? CMTextAttachment, url = textAttachment.url {
            UIApplication.sharedApplication().openURL(url)
            return false
        }
        return true
    }

    func textViewDidEndEditing(textView: UITextView) {
        print("DID END PARSING")
    }
}

