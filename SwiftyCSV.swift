//
//  SwiftyCSV.swift
//  SwiftyCSV
//
//  Created by Chris Foreman on 5/6/20.
//  Copyright © 2020 Chris Foreman. All rights reserved.
//

import Foundation


class CSV<T> {
    
    //MARK: Mutable Properties
    
    ///This will be the file's name.
    var name:String
    
    ///If a field's format closure isn't set and a value is an empty string, it will be replaced with this value.
    ///Works for all fields collectively so you don't have to specify empty value formatting for each field manually.
    ///Default value is an empty string
    var defaultEmptyValue:String = ""
    
    ///If a cell's value is nil, it will be replaced with this value.
    ///Works for all fields collectively so you don't have to specify nil value formatting for each field manually.
    ///Default value is an empty string
    var defaultNilValue:String = ""
    
    ///The default value is "vertical" where the data is listed rows by row.
    ///A horizontal direction makes the data listed column by column (left to right)
    var listDirection:ListDirection = .vertical
    
    var items:[T]
    
    //MARK: Private properties
    
    private var fields = [(name: String, path: PartialKeyPath<T>)]()
    
    private var closureDict = [String:((String?) -> (String))]()
    
    //MARK: Initialization
    
    init(name: String, items: [T]) {
        self.name = name
        self.items = items
    }
    
    //MARK: Public Methods
    
    func addField<V>(_ name:String, prop: WritableKeyPath<T,V>, closure: ((String?) -> String)? = nil) {
        //Each field name acts as one of the fields for the list which is bound to a keypath.
        fields.append((name, prop))
        //Just returns the cell's value with the default formatting.
        let defaultClosure:((String?) -> String) = { (value) in
            if let nonNil = value {
                return nonNil.isEmpty ? self.defaultEmptyValue : nonNil
            }else{
                return self.defaultNilValue
            }
        }
        //Uses the default closure if no special closure was specified.
        closureDict[name] = closure ?? defaultClosure
    }
    
    
    ///Creates the data that can be used to save as a csv file.
    func createData() throws -> Data {
        //An object in a database shouldn't have 2 identical fields.
        let headings = self.fields.map { $0.name }
        if hasDuplicate(headings) {
            throw ContentError.duplicateHeadings
        }
        let text = listDirection == .vertical ? verticalList() : horizontalList()
        guard let data = text.data(using: .utf8) else {
            throw ContentError.textEncoding
        }
        return data
    }
    
    
    //MARK: Private Methods
    
    ///Creates a string formatted for a horizontal csv list.
    private func horizontalList() -> String {
        var text:String = ""
        //Loop through items for the field. (Kind of like the inverse of the horizontal method)
        for field in fields {
            //Need to start each row off with the heading.
            var cellItems:[Any] = [field.name]
            for item in items {
                let value = String(describing: item[keyPath: field.path])
                //Safe to force unwrap because the heading is guarunteed to be in the dictionary.
                let formatted = closureDict[field.name]!(value)
                cellItems.append(formatted)
            }
            text += CSV.csvLine(from: cellItems)
        }
        return text
    }
    
    
    ///Creates a string formatted for a vertical csv list.
    private func verticalList() -> String {
        let headingNames:[String] = self.fields.map { $0.name }
        var text:String = CSV.csvLine(from: headingNames)
        //Loop through the fields for an item.
        for item in items {
            var cellItems = [Any]()
            for field in fields {
                let value = "\(item[keyPath: field.path])"
                //Safe to force unwrap because the heading is guarunteed to be in the dictionary.
                let formatted = closureDict[field.name]!(value)
                cellItems.append(formatted)
            }
            text += CSV.csvLine(from: cellItems)
        }
        return text
    }
    
    
    ///Take a collection of items and returns a formatted string so that each element in the collection will be within its own cell in the csv.
    private static func csvLine(from items: [Any]) -> String {
        var line = ""
        for (index, item) in items.enumerated() {
            let item = item
            if index < items.count - 1 { line.append("\"\(item)\",") }
            else{ line.append("\"\(item)\"\n") }
        }
        return line
    }
    
    //Checks if an array contains a duplicate value.
    private func hasDuplicate(_ array: [String]) -> Bool {
        var dict = [String:Bool]()
        for element in array {
            if dict[element] != nil { return true }
            dict[element] = true
        }
        return false
    }
    
}

//MARK: CSV Enums

extension CSV {
    
    enum ListDirection {
        case horizontal
        case vertical
    }
    
    enum ContentError:Error {
        case duplicateHeadings
        case textEncoding
    }
    
}
