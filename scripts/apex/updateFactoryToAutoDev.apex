List<Automobile__c> rows = [
    SELECT Id, Bought_Via__c
    FROM Automobile__c
    WHERE Bought_Via__c = 'Factory'
    AND CreatedDate >= 2026-03-23T23:52:00Z
    AND CreatedDate <= 2026-03-23T23:55:30Z
    LIMIT 200
];

for (Automobile__c row : rows) {
    row.Bought_Via__c = 'Auto.dev';
}

Database.SaveResult[] results = Database.update(rows, false);
Integer updated = 0;
Integer failed = 0;
for (Database.SaveResult r : results) {
    if (r.isSuccess()) {
        updated++;
    } else {
        failed++;
        for (Database.Error e : r.getErrors()) {
            System.debug('UPDATE_FACTORY_TO_AUTODEV_ERROR ' + e.getStatusCode() + ': ' + e.getMessage());
        }
    }
}
System.debug('UPDATE_FACTORY_TO_AUTODEV updated=' + updated + ' failed=' + failed + ' total=' + rows.size());
