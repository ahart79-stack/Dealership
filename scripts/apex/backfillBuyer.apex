// Backfill Buyer__c on already-sold Automobile__c records
List<Contact> contacts = [SELECT Id FROM Contact LIMIT 200];
if (contacts.isEmpty()) {
    System.debug('No contacts found — run Create Contacts first.');
} else {
    List<Automobile__c> soldAutos = [
        SELECT Id
        FROM Automobile__c
        WHERE Buyer__c = null
          AND RecordType.DeveloperName = 'Sold'
        LIMIT 10000
    ];

    List<Automobile__c> updates = new List<Automobile__c>();
    Integer poolSize = contacts.size();
    Integer i = 0;
    for (Automobile__c auto : soldAutos) {
        Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), poolSize);
        updates.add(new Automobile__c(Id = auto.Id, Buyer__c = contacts[idx].Id));
        i++;
    }

    Database.SaveResult[] results = Database.update(updates, false);
    Integer success = 0;
    Integer failed = 0;
    for (Database.SaveResult r : results) {
        if (r.isSuccess()) { success++; } else { failed++; }
    }
    System.debug('Backfill complete. Updated: ' + success + ', Failed: ' + failed);
}
