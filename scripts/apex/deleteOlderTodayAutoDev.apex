List<Automobile__c> latestRows = [
    SELECT Id, CreatedDate
    FROM Automobile__c
    WHERE Bought_Via__c = 'Auto.dev'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (!latestRows.isEmpty()) {
    Datetime cutoff = latestRows[0].CreatedDate;
    List<Automobile__c> rowsToDelete = [
        SELECT Id
        FROM Automobile__c
        WHERE Bought_Via__c = 'Auto.dev'
        AND CreatedDate = TODAY
        AND CreatedDate < :cutoff
    ];

    delete rowsToDelete;
    System.debug('AUTO_DEV_DELETE_OLDER cutoff=' + String.valueOf(cutoff) + ' deleted=' + rowsToDelete.size());
} else {
    System.debug('AUTO_DEV_DELETE_OLDER no Auto.dev rows found for TODAY');
}
