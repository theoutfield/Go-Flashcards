//
//  Stack.swift
//  FlashCards
//
//  Created by Roy McKenzie on 12/23/16.
//  Copyright © 2016 Roy McKenzie. All rights reserved.
//

import CloudKit
import RealmSwift

private let NoCards = NSLocalizedString("No cards", comment: "No cards in the stack")
private let AllCardsMastered = NSLocalizedString("All cards mastered", comment: "All cards are mastered")
private let AmountToReview = NSLocalizedString("%@ to review", comment: "X amount of cards to review")
private let XofXMastered = NSLocalizedString("%i of %@ mastered", comment: "X of X cards mastered")

final class Stack: Object {
    dynamic var name: String = ""
    dynamic var preferences: StackPreferences? = nil
    let cards = List<Card>()
    
    // CloudKitSyncable
    dynamic var id: String = UUID().uuidString
    dynamic var synced: Date? = nil
    dynamic var modified: Date = Date()
    dynamic var deleted: Date? = nil
    dynamic var recordChangeTag: String? = nil
    dynamic var recordOwnerName: String? = CKOwnerDefaultName
}

// MARK:- CloudKitSyncable
extension Stack: CloudKitSyncable {
    typealias RecordZoneType = StackZone
    
    var record: CKRecord {
        let record = CKRecord(recordType: .stack, recordID: recordID)
        record.setObject(name as NSString, forKey: RecordType.Stack.name.rawValue)
        return record
    }
    
    private var undeletedCards: Results<Card> {
        let predicate = NSPredicate(format: "deleted == nil")
        return cards.filter(predicate)
    }
    
    // TODO:- Use sorting by keyPath once realm releases support
    var sortedCards: Results<Card> {
        return undeletedCards.sorted(byKeyPath: "order")
    }
    
    // TODO:- Use sorting by keyPath once realm releases support
    var masteredCards: Results<Card> {
        let predicate = NSPredicate(format: "mastered != nil")
        return sortedCards.filter(predicate)
    }

    // TODO:- Use sorting by keyPath once realm releases support
    var unmasteredCards: Results<Card> {
        let predicate = NSPredicate(format: "mastered == nil")
        return sortedCards.filter(predicate)
    }
}

// MARK:- CloudKitCodable
extension Stack: CloudKitCodable {
    
    convenience init?(record: CKRecord) throws {
        self.init()
        let decoder = CloudKitDecoder(record: record)
        id              = decoder.recordName
        modified        = decoder.modified
        recordChangeTag = decoder.recordChangeTag
        recordOwnerName = decoder.recordOwnerName
        name            = try decoder.decode("name")
    }
}

// MARK:- initialize a new Stack from a QuizletStack
extension Stack {
    
    convenience init(stack: QuizletStack) {
        self.init()
        self.name = stack.name
    }
}

// MARK:- Indexing and primary keys
extension Stack {
    
    override open class func primaryKey() -> String? {
        return "id"
    }
    
    override open class func indexedProperties() -> [String] {
        return [
            "synced",
            "modified",
            "recordOwnerName"
        ]
    }
}

// MARK:- View model
extension Stack {
    
    var progressDescription: String {
        
        let detailText: String
        
        switch (unmasteredCards.count, masteredCards.count) {
        case (0, 0):
            detailText = NoCards
        case (0, let masteredCount) where masteredCount > 0:
            detailText = AllCardsMastered
        case (let unmasteredCount, 0) where unmasteredCount > 0:
            let localized = AmountToReview
            let localizedWithNumber = String(format: localized, arguments: [cardTextPlurality(unmasteredCount)])
            detailText = localizedWithNumber
        case (let unmasteredCount, let masteredCount) where unmasteredCount > 0 && masteredCount > 0:
            let localized = XofXMastered
            let localizedWithNumber = String(format: localized, arguments: [masteredCount, cardTextPlurality(cards.count)])
            detailText = localizedWithNumber
        default:
            detailText = ""
        }
        
        return detailText
    }
    
    func cardTextPlurality(_ count: Int) -> String {
        switch count {
        case 0: return NSLocalizedString("No cards", comment: "No cards")
        case 1: return NSLocalizedString("One card", comment: "One card")
        default:
            let localized = NSLocalizedString("%i cards", comment: "X cards")
            let localizedWithNumber = String(format: localized, arguments: [count])
            return localizedWithNumber
        }
    }
    
    // Notifications
    var notificationInterval: NSCalendar.Unit? {
        guard let interval = preferences?.notificationInterval else {
            return nil
        }
        switch interval {
        case "day":
            return .day
        case "hour":
            return .hour
        default:
            return nil
        }
    }
    
    var notificationEnabled: Bool {
        guard let preferences = preferences else {
            return false
        }
        return preferences.notificationEnabled
    }

    var notificationStartDate: Date? {
        return preferences?.notificationStartDate
    }

    var notificationStartDateString: String? {
        guard let notificationStartDate = notificationStartDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: notificationStartDate)
    }
}
