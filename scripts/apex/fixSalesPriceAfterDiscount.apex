// Fix Sales_Price__c on records that already have a discount applied.
// Sales_Price__c = Value__c - discount_amount
List<Automobile__c> autos = [
    SELECT Id, Value__c, X30_60_Discount__c, X60_90_Discount__c
    FROM Automobile__c
    WHERE Value__c != NULL
    AND (X30_60_Discount__c != NULL OR X60_90_Discount__c != NULL)
    LIMIT 2000
];

List<Automobile__c> toUpdate = new List<Automobile__c>();
for (Automobile__c a : autos) {
    Decimal discount = a.X60_90_Discount__c != null ? a.X60_90_Discount__c : a.X30_60_Discount__c;
    toUpdate.add(new Automobile__c(
        Id             = a.Id,
        Sales_Price__c = (a.Value__c - discount).setScale(2)
    ));
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
}
System.debug('Fixed Sales_Price__c on ' + toUpdate.size() + ' discounted records.');
