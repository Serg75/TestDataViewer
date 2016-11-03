//
//  Extensions.swift
//  testDataViewer
//
//  Created by Sergey Slobodenyuk on 01/11/16.
//  Copyright © 2016 Elements Interactive. All rights reserved.
//

import Foundation
import UIKit

public extension String {
    public func attributedFromHTML() -> NSAttributedString {
        let data = self.data(using: String.Encoding.utf8)!
        
        let options = [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType as AnyObject, NSCharacterEncodingDocumentAttribute: NSNumber(value: String.Encoding.utf8.rawValue) as Any] as [String:Any]
        
        do {
            let attrStr = try NSAttributedString(data:data, options:options, documentAttributes:nil)
            return attrStr
        }
        catch {
            return NSAttributedString(string: self)
        }
    }
}

public extension UILabel {
    public func setAttributedTextWithoutFont(text: NSAttributedString) {
        
        // reset previous attributes for reusable controls
        attributedText = nil
        
        if font == nil {
            font = UIFont.systemFont(ofSize:UIFont.systemFontSize)
        }
        
        let fullRange = NSMakeRange(0, text.length)
        let newAttributeText = text.mutableCopy() as! NSMutableAttributedString
        newAttributeText.enumerateAttribute(NSFontAttributeName, in: fullRange, options: NSAttributedString.EnumerationOptions.longestEffectiveRangeNotRequired) {
            (attribute: Any!, range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
            if let attributeFont = attribute as? UIFont {
                let extraTraits = attributeFont.fontDescriptor.symbolicTraits.intersection([.traitItalic,  .traitBold])
                if !extraTraits.isEmpty {
                    let newFontDescriptor = font.fontDescriptor.withSymbolicTraits(extraTraits)
                    let newFont = UIFont(descriptor: newFontDescriptor!, size: font.pointSize)
                    newAttributeText.addAttribute(NSFontAttributeName, value: newFont, range: range)
                } else {
                    print("\(text) >>> \(font.fontDescriptor.symbolicTraits)")
                    newAttributeText.addAttribute(NSFontAttributeName, value: font, range: range)
                }
            }
        }
        attributedText = newAttributeText
    }
}
