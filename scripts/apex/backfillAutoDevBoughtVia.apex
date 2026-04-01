List<Automobile__c> updates = [
    SELECT Id, Bought_Via__c
    FROM Automobile__c
    WHERE Bought_Via__c = null
    AND CreatedDate >= 2026-03-23T23:52:00Z
    AND CreatedDate <= 2026-03-23T23:55:30Z
    LIMIT 1000
];

for (Automobile__c row : updates) {
    row.Bought_Via__c = 'Auto.dev';
}

Database.SaveResult[] results = Database.update(updates, false);
Integer succeeded = 0;
Integer failed = 0;

for (Database.SaveResult result : results) {
    if (result.isSuccess()) {
        succeeded++;
    } else {
        failed++;
        for (Database.Error err : result.getErrors()) {
            System.debug('AUTO_DEV_BOUGHT_VIA_BACKFILL_ERROR ' + err.getStatusCode() + ': ' + err.getMessage());
        }
    }
}

System.debug('AUTO_DEV_BOUGHT_VIA_BACKFILL updated=' + succeeded + ' failed=' + failed + ' total=' + updates.size());