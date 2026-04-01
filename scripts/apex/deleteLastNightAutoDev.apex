List<Automobile__c> rows = [
    SELECT Id
    FROM Automobile__c
    WHERE Bought_Via__c = 'Auto.dev'
    AND CreatedDate = YESTERDAY
];

delete rows;
System.debug('AUTO_DEV_DELETE deleted=' + rows.size());
