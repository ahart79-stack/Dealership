Schema.SObjectField f = Schema.SObjectType.Automobile__c.fields.getMap().get('Bought_Via__c');
String picked;
for (Schema.PicklistEntry pe : f.getDescribe().getPicklistValues()) {
    if (pe.getValue().startsWith('Auto')) {
        picked = pe.getValue();
        System.debug('PICKED value=[' + picked + '] len=' + picked.length());
    }
}
Automobile__c row = [SELECT Id, Bought_Via__c FROM Automobile__c WHERE Id = 'a04g5000000ypFlAAI' LIMIT 1];
row.Bought_Via__c = picked;
Database.SaveResult sr = Database.update(row, false);
System.debug('PROBE success=' + sr.isSuccess());
if (!sr.isSuccess()) {
    for (Database.Error e : sr.getErrors()) {
        System.debug('PROBE_ERR ' + e.getStatusCode() + ': ' + e.getMessage());
    }
}
