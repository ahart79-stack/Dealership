Set<Id> automobileIdsWithPurchases = new Set<Id>();
for (Purchase__c purchase : [
    SELECT Automobile__c
    FROM Purchase__c
    WHERE Automobile__c != null
]) {
    automobileIdsWithPurchases.add(purchase.Automobile__c);
}

List<Automobile__c> soldAutos = [
    SELECT Id, Buyer__c, Make__c, Year__c, Sold__c, Sold_Price__c
    FROM Automobile__c
    WHERE RecordType.DeveloperName = 'Sold'
      AND Buyer__c != null
];

List<Purchase__c> purchasesToInsert = new List<Purchase__c>();
for (Automobile__c auto : soldAutos) {
    if (automobileIdsWithPurchases.contains(auto.Id)) {
        continue;
    }

    purchasesToInsert.add(new Purchase__c(
        Automobile__c = auto.Id,
        Contact__c = auto.Buyer__c,
        Make__c = auto.Make__c,
        Year__c = auto.Year__c == null ? null : String.valueOf(auto.Year__c),
        Purchased_Date__c = auto.Sold__c,
        Purchase_Price__c = auto.Sold_Price__c == null ? null : auto.Sold_Price__c.setScale(2)
    ));
}

Integer successCount = 0;
Integer failureCount = 0;
if (!purchasesToInsert.isEmpty()) {
    Database.SaveResult[] results = Database.insert(purchasesToInsert, false);
    for (Database.SaveResult result : results) {
        if (result.isSuccess()) {
            successCount++;
        } else {
            failureCount++;
            for (Database.Error err : result.getErrors()) {
                System.debug('Purchase backfill error: ' + err.getMessage());
            }
        }
    }
}

System.debug('Purchase backfill complete. Inserted: ' + successCount + ', Failed: ' + failureCount);