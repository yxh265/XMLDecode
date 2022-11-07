//
//  XMLDecode.swift
//  利用系统原生库XMLParser，把标准的XML转成Dictionary
//
//  Created by yuxuhong on 2022/9/5.
//

import Foundation

public class XMLDecode: NSObject {
    // XMLParserDelegate需要NSObject
    
    public enum XMLInfo {
        case xmlURL(url: URL?)
        case xmlData(data: Data?)
    }
    public var callback: (([String: Any]?) -> Void)?
    
    private var stack: [Any] = []
    private var curElementName: String = ""
    
    // 按回调返回，xml的解码用普通线程
    public func getDictionary(with xml: XMLInfo, callback: @escaping (([String: Any]?) -> Void)) {
        if case let .xmlURL(url) = xml, let url = url, let parser = XMLParser(contentsOf: url) {
            _ = getDictionaryWithParser(parser: parser, callback: callback)
        } else if case let .xmlData(data) = xml, let data = data {
            let parser = XMLParser(data: data)
            _ = getDictionaryWithParser(parser: parser, callback: callback)
        } else {
            callback(nil)
        }
    }
    
    // 按函数返回，xml的解码用主线程，如何xml太大会卡主线程
    public func getDictionary(with xml: XMLInfo) -> [String: Any]? {
        if case let .xmlURL(url) = xml, let url = url, let parser = XMLParser(contentsOf: url) {
            return getDictionaryWithParser(parser: parser, callback: nil)
        } else if case let .xmlData(data) = xml, let data = data {
            let parser = XMLParser(data: data)
            return getDictionaryWithParser(parser: parser, callback: nil)
        }
        return nil
    }
    
    private func getDictionaryWithParser(parser: XMLParser, callback: (([String: Any]?) -> Void)?) -> [String: Any]? {
        self.callback = callback
        
        if callback != nil {
            DispatchQueue.global().async {
                parser.delegate = self
                parser.parse()
            }
        } else {
            parser.delegate = self
            parser.parse()
            if let result = stack.last as? [String: Any] {
                return result
            }
        }
        return nil
    }
}

extension XMLDecode: XMLParserDelegate {
    public func parserDidEndDocument(_ parser: XMLParser){
        if let result = stack.last as? [String: Any] {
            self.callback?(result)
        } else {
            self.callback?(nil)
        }
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("XMLDecode parseError:", parseError)
    }
    
    public func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        print("XMLDecode validationError:", validationError)
    }
    
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        parserStart(elementName: elementName, attributes: attributeDict)
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        let newString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        parserTextValue(newString)
    }
    
    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8), string.count > 0 {
            parserTextValue(string)
        }
    }
    
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        parserEnd(elementName: elementName)
    }
}

extension XMLDecode {
    private func parserStart(elementName: String, attributes: [String : String]) {
        self.curElementName = elementName
        
        stack.append(elementName)
    }
    
    private func parserTextValue(_ string: String) {
        if string != "" {
            let last = stack.popLast()
            if let last = last as? String, last == self.curElementName {
                stack.append([last: string])
            } else if let last = last as? [String: Any], let topElementValue = last[self.curElementName] as? String {
                stack.append([self.curElementName: topElementValue + string])
            }
        }
    }
    
    private func parserEnd(elementName: String) {
        var isInStack = false
        for item in stack {
            if (item as? String) == elementName {
                isInStack = true
                break
            }
        }
        if isInStack {
            var tempDict: [String: Any] = [:]
            repeat {
                let last = stack.last
                if (last as? String) == elementName {
                    break
                }
                if let dict = (last as? [String: Any]) {
                    tempDict = mergingItem(itemLeft: tempDict, itemRight: dict)
                }
            } while stack.popLast() != nil
            
            _ = stack.popLast()
            
            var itemValue: Any?
            for (index, item) in stack.enumerated() {
                if let dict = (item as? [String: Any]), let dictValue = dict[elementName] {
                    itemValue = dictValue
                    stack.remove(at: index)
                    break
                }
            }
            if var itemValue = itemValue as? [Any] {
                itemValue.append(tempDict)
                stack.append([elementName: itemValue])
            } else if let itemValue = itemValue as? [String: Any] {
                stack.append([elementName: [itemValue, tempDict]])
            } else {
                stack.append([elementName: tempDict])
            }
        }
    }
    
    private func mergingItem(itemLeft: [String: Any], itemRight: [String: Any]) -> [String: Any] {
        var itemDict = itemLeft
        for (key, value) in itemDict {
            if let rightValue = itemRight[key] {
                if var leftValue = value as? [Any] {
                    leftValue.append(rightValue)
                    itemDict[key] = leftValue
                } else {
                    itemDict[key] = [value, rightValue]
                }
                return itemDict
            }
        }
        return itemDict.merging(itemRight) { $1 }
    }
}
