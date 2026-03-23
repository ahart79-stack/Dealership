// Fix existing New automobiles so Bought_Price__c is 30% less than Value__c.
List<Automobile__c> autos = [
    SELECT Id, Value__c, Bought_Price__c
    FROM Automobile__c
    WHERE RecordType.DeveloperName = 'New'
    AND Value__c != null
    LIMIT 5000
];

List<Automobile__c> toUpdate = new List<Automobile__c>();
for (Automobile__c a : autos) {
    Decimal expected = (a.Value__c * Decimal.valueOf('0.70')).setScale(2);
    if (a.Bought_Price__c == null || a.Bought_Price__c != expected) {
        toUpdate.add(new Automobile__c(
            Id = a.Id,
            Bought_Price__c = expected
        ));
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
}

System.debug('Fixed Bought_Price__c on ' + toUpdate.size() + ' New records.');
