Map<Id, Purchase__c> purchaseByAutomobileId = new Map<Id, Purchase__c>();
for (Purchase__c purchase : [
    SELECT Id, Automobile__c, Contact__c, Purchased_Date__c, Purchase_Price__c
    FROM Purchase__c
    WHERE Automobile__c != null
]) {
    purchaseByAutomobileId.put(purchase.Automobile__c, purchase);
}

List<Automobile__c> automobiles = [
    SELECT Id, Buyer__c, Sold__c, Sold_Price__c
    FROM Automobile__c
    WHERE Id IN :purchaseByAutomobileId.keySet()
];

List<Automobile__c> updates = new List<Automobile__c>();
for (Automobile__c automobile : automobiles) {
    Purchase__c purchase = purchaseByAutomobileId.get(automobile.Id);
    Boolean needsUpdate = false;
    Automobile__c updateRow = new Automobile__c(Id = automobile.Id);

    if (automobile.Buyer__c != purchase.Contact__c) {
        updateRow.Buyer__c = purchase.Contact__c;
        needsUpdate = true;
    }
    if (automobile.Sold__c != purchase.Purchased_Date__c) {
        updateRow.Sold__c = purchase.Purchased_Date__c;
        needsUpdate = true;
    }

    Decimal automobileSoldPrice = automobile.Sold_Price__c == null ? null : automobile.Sold_Price__c.setScale(2);
    Decimal purchasePrice = purchase.Purchase_Price__c == null ? null : purchase.Purchase_Price__c.setScale(2);
    if (automobileSoldPrice != purchasePrice) {
        updateRow.Sold_Price__c = purchasePrice;
        needsUpdate = true;
    }

    if (needsUpdate) {
        updates.add(updateRow);
    }
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
                System.debug('Automobile sync error: ' + err.getMessage());
            }
        }
    }
}

System.debug('Automobile sync complete. Updated: ' + successCount + ', Failed: ' + failureCount);