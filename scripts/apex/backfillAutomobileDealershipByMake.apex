Map<String, Id> makeToDealerId = new Map<String, Id>();
for (typeofdealership__c d : [
    SELECT Id, Name
    FROM typeofdealership__c
]) {
    makeToDealerId.put(d.Name, d.Id);
}

List<Automobile__c> autosToUpdate = [
    SELECT Id, Make__c, Type_of_Dealership__c
    FROM Automobile__c
    WHERE Type_of_Dealership__c = null
    AND Make__c != null
    LIMIT 50000
];

Integer updated = 0;
for (Automobile__c a : autosToUpdate) {
    Id dealerId = makeToDealerId.get(a.Make__c);
    if (dealerId != null) {
        a.Type_of_Dealership__c = dealerId;
        updated++;
    }
}

if (!autosToUpdate.isEmpty()) {
    update autosToUpdate;
}

System.debug('Automobile dealership backfill complete. Candidates=' + autosToUpdate.size() + ', updated=' + updated);
