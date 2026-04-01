List<Automobile__c> rowsToDelete = [
    SELECT Id
    FROM Automobile__c
    WHERE Bought_Via__c = 'Auto.dev'
    AND Value__c = 0
];

delete rowsToDelete;
System.debug('AUTO_DEV_DELETE_ZERO_VALUE deleted=' + rowsToDelete.size());
