Automobile__c row = [SELECT Id, Bought_Via__c FROM Automobile__c WHERE Id = 'a04g5000000ypFlAAI' LIMIT 1];
row.Bought_Via__c = 'Auto_dev';
Database.SaveResult sr = Database.update(row, false);
System.debug('PROBE_UNDERSCORE success=' + sr.isSuccess());
if (!sr.isSuccess()) {
    for (Database.Error e : sr.getErrors()) {
        System.debug('PROBE_UNDERSCORE_ERR ' + e.getStatusCode() + ': ' + e.getMessage());
    }
}
