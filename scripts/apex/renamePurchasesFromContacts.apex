// Rename existing Purchase__c records to match the naming convention:
// "[Contact Name] - [Purchase Created Date]"
// "[Contact Name] - [Purchase Created Date] - 2" for multiples from same contact

Map<Id, String> contactNameById = new Map<Id, String>();
for (Contact c : [SELECT Id, Name FROM Contact]) {
    contactNameById.put(c.Id, c.Name);
}

// Retrieve all purchases ordered by contact then by creation date so sequential
// numbering within each contact group is chronologically stable
List<Purchase__c> purchases = [
    SELECT Id, Contact__c, CreatedDate
    FROM Purchase__c
    WHERE Contact__c != null
    ORDER BY Contact__c ASC, CreatedDate ASC NULLS LAST
];

// Track how many purchases we have assigned per contact so far
Map<Id, Integer> countByContact = new Map<Id, Integer>();
List<Purchase__c> updates = new List<Purchase__c>();

for (Purchase__c purchase : purchases) {
    String contactName = contactNameById.get(purchase.Contact__c);
    if (contactName == null) {
        continue;
    }

    // Date string in YYYY-MM-DD format to match TEXT(TODAY()) in the flow
    String dateStr = purchase.CreatedDate == null
        ? String.valueOf(System.today())
        : String.valueOf(purchase.CreatedDate.date());

    Integer seq = countByContact.containsKey(purchase.Contact__c)
        ? countByContact.get(purchase.Contact__c) + 1
        : 1;
    countByContact.put(purchase.Contact__c, seq);

    String newName = seq == 1
        ? contactName + ' - ' + dateStr
        : contactName + ' - ' + dateStr + ' - ' + seq;

    // Truncate to 80 chars (the Name field limit)
    if (newName.length() > 80) {
        newName = newName.left(80);
    }

    updates.add(new Purchase__c(Id = purchase.Id, Name = newName));
}

Integer successCount = 0;
Integer failureCount = 0;
if (!updates.isEmpty()) {
    Database.SaveResult[] results = Database.update(updates, false);
    for (Database.SaveResult result : results) {
        if (result.isSuccess()) {
            successCount++;
        } else {
            failureCount++;
            for (Database.Error err : result.getErrors()) {
                System.debug('Purchase rename error: ' + err.getMessage());
            }
        }
    }
}

System.debug('Purchase rename complete. Updated: ' + successCount + ', Failed: ' + failureCount);
