Id managerRtId;
List<RecordType> rts = [
    SELECT Id
    FROM RecordType
    WHERE SObjectType = 'Contact' AND DeveloperName = 'Manager'
    LIMIT 1
];
if (rts.isEmpty()) {
    throw new AuraHandledException('Contact record type Manager was not found.');
}
managerRtId = rts[0].Id;

Map<String, Schema.SObjectField> locationFields = Schema.SObjectType.Location.fields.getMap();
String accountField = null;
if (locationFields.containsKey('Account__c')) {
    accountField = 'Account__c';
} else if (locationFields.containsKey('AccountId')) {
    accountField = 'AccountId';
}

String soql = 'SELECT Id, Name';
if (accountField != null) {
    soql += ', ' + accountField;
}
soql += ' FROM Location WHERE Location_Manager__c = null ORDER BY CreatedDate ASC LIMIT 20';

List<SObject> locationRows = Database.query(soql);
if (locationRows.isEmpty()) {
    System.debug('LOCATION_MANAGER_BACKFILL no-op: no locations missing Location_Manager__c');
    return;
}

String[] firstNames = new String[]{'Alex','Jordan','Taylor','Morgan','Casey','Riley','Avery','Parker'};
String[] lastNames = new String[]{'Bennett','Carter','Davis','Ellis','Foster','Griffin','Hayes','Kennedy'};

List<Contact> contactsToInsert = new List<Contact>();
for (Integer i = 0; i < locationRows.size(); i++) {
    SObject row = locationRows[i];
    Contact c = new Contact();
    c.FirstName = firstNames[Math.mod(Math.abs(Crypto.getRandomInteger()), firstNames.size())];
    c.LastName = lastNames[Math.mod(Math.abs(Crypto.getRandomInteger()), lastNames.size())];
    c.RecordTypeId = managerRtId;
    c.Phone = '555-' + String.valueOf(100 + Math.mod(Math.abs(Crypto.getRandomInteger()), 900))
        + '-' + String.valueOf(1000 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9000));
    if (accountField != null && row.get(accountField) != null) {
        c.AccountId = (Id)row.get(accountField);
    }
    contactsToInsert.add(c);
}

Database.SaveResult[] contactResults = Database.insert(contactsToInsert, false);
List<Schema.Location> locationsToUpdate = new List<Schema.Location>();
Integer prepared = 0;
for (Integer i = 0; i < locationRows.size(); i++) {
    if (!contactResults[i].isSuccess()) {
        continue;
    }
    Schema.Location loc = new Schema.Location();
    loc.Id = (Id)locationRows[i].get('Id');
    loc.Location_Manager__c = contactResults[i].getId();
    locationsToUpdate.add(loc);
    prepared++;
}

Integer updated = 0;
if (!locationsToUpdate.isEmpty()) {
    Database.SaveResult[] locResults = Database.update(locationsToUpdate, false);
    for (Database.SaveResult sr : locResults) {
        if (sr.isSuccess()) {
            updated++;
        }
    }
}

System.debug('LOCATION_MANAGER_BACKFILL scanned=' + locationRows.size() + ' contactsInserted=' + prepared + ' locationsUpdated=' + updated);
