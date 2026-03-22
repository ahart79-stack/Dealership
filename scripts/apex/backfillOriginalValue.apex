// Backfill Original_Value__c for existing Automobile__c records where it is null
List<Automobile__c> autos = [
    SELECT Id, Value__c
    FROM Automobile__c
    WHERE Original_Value__c = null
    AND Value__c != null
    LIMIT 2000
];

for (Automobile__c a : autos) {
    a.Original_Value__c = a.Value__c;
}

if (!autos.isEmpty()) {
    update autos;
}
System.debug('Backfilled Original_Value__c on ' + autos.size() + ' records.');
