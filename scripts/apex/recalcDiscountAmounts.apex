// Recalculate X30_60_Discount__c and X60_90_Discount__c to store the discount AMOUNT
// (difference in price) instead of the discounted price.
// Runs over all records that already have a discount value set.
Date today = Date.today();
List<Automobile__c> autos = [
    SELECT Id, Bought__c, Value__c, X30_60_Discount__c, X60_90_Discount__c
    FROM Automobile__c
    WHERE Value__c != NULL
    AND (X30_60_Discount__c != NULL OR X60_90_Discount__c != NULL)
    LIMIT 2000
];

List<Automobile__c> toUpdate = new List<Automobile__c>();
for (Automobile__c a : autos) {
    if (a.Bought__c == null) { continue; }
    Integer days = a.Bought__c.daysBetween(today);
    Automobile__c upd = new Automobile__c(Id = a.Id);
    if (days > 60 && a.X60_90_Discount__c != null) {
        upd.X60_90_Discount__c = (a.Value__c * 0.25).setScale(2);
    } else if (days >= 30 && a.X30_60_Discount__c != null) {
        upd.X30_60_Discount__c = (a.Value__c * 0.15).setScale(2);
    } else {
        continue;
    }
    toUpdate.add(upd);
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
}
System.debug('Recalculated discount amounts on ' + toUpdate.size() + ' records.');
