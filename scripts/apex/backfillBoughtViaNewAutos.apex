List<Automobile__c> autosToUpdate = [
    SELECT Id, Bought_Via__c
    FROM Automobile__c
    WHERE RecordType.DeveloperName = 'New'
    AND Bought_Via__c = null
    LIMIT 10000
];

for (Automobile__c auto : autosToUpdate) {
    auto.Bought_Via__c = 'Factory';
}

Database.SaveResult[] results = Database.update(autosToUpdate, false);
Integer updated = 0;
Integer failed = 0;

for (Database.SaveResult result : results) {
    if (result.isSuccess()) {
        updated++;
    } else {
        failed++;
        for (Database.Error err : result.getErrors()) {
            System.debug('Failed to update Automobile__c: ' + err.getMessage());
        }
    }
}

System.debug('Bought_Via__c backfill complete. Updated: ' + updated + ', Failed: ' + failed);