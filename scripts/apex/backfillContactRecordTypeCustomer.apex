Id customerRecordTypeId;
Map<String, Schema.RecordTypeInfo> byDev = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
Map<String, Schema.RecordTypeInfo> byName = Schema.SObjectType.Contact.getRecordTypeInfosByName();

if (byDev.containsKey('Customer')) {
    customerRecordTypeId = byDev.get('Customer').getRecordTypeId();
} else if (byName.containsKey('Customer')) {
    customerRecordTypeId = byName.get('Customer').getRecordTypeId();
}

if (customerRecordTypeId == null) {
    throw new AuraHandledException('Contact record type "Customer" was not found.');
}

Set<Id> buyerIds = new Set<Id>();
for (Automobile__c a : [SELECT Buyer__c FROM Automobile__c WHERE Buyer__c != null]) {
    buyerIds.add(a.Buyer__c);
}
for (Purchase__c p : [SELECT Contact__c FROM Purchase__c WHERE Contact__c != null]) {
    buyerIds.add(p.Contact__c);
}

List<Contact> toUpdate = new List<Contact>();
for (Contact c : [
    SELECT Id, RecordTypeId
    FROM Contact
    WHERE Id IN :buyerIds
]) {
    if (c.RecordTypeId != customerRecordTypeId) {
        c.RecordTypeId = customerRecordTypeId;
        toUpdate.add(c);
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
}

System.debug('CONTACT_CUSTOMER_BACKFILL buyers=' + buyerIds.size() + ', updated=' + toUpdate.size());
