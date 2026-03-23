List<Purchase__c> purchases = [
    SELECT Id, Automobile__r.Sold__c, Automobile__r.Sold_Price__c
    FROM Purchase__c
    WHERE Automobile__c != null
];

List<Purchase__c> updates = new List<Purchase__c>();
for (Purchase__c purchase : purchases) {
    updates.add(new Purchase__c(
        Id = purchase.Id,
        Purchased_Date__c = purchase.Automobile__r == null ? null : purchase.Automobile__r.Sold__c,
        Purchase_Price__c = purchase.Automobile__r == null || purchase.Automobile__r.Sold_Price__c == null
            ? null
            : purchase.Automobile__r.Sold_Price__c.setScale(2)
    ));
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
                System.debug('Purchase field backfill error: ' + err.getMessage());
            }
        }
    }
}

System.debug('Purchase field backfill complete. Updated: ' + successCount + ', Failed: ' + failureCount);