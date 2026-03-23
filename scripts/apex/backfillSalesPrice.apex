// Backfill Sales_Price__c from Value__c for existing records where it is null
List<Automobile__c> autos = [
    SELECT Id, Value__c
    FROM Automobile__c
    WHERE Sales_Price__c = null
    AND Value__c != null
    LIMIT 2000
];

for (Automobile__c a : autos) {
    a.Sales_Price__c = a.Value__c;
}

if (!autos.isEmpty()) {
    update autos;
}
System.debug('Backfilled Sales_Price__c on ' + autos.size() + ' records.');
