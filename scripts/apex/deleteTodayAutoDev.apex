List<Automobile__c> rows = [
    SELECT Id
    FROM Automobile__c
    WHERE Bought_Via__c = 'Auto.dev' AND CreatedDate = TODAY
];
Integer deletedCount = rows.size();
if (!rows.isEmpty()) {
    delete rows;
}
System.debug('AUTO_DEV_DELETE_TODAY deleted=' + deletedCount);
