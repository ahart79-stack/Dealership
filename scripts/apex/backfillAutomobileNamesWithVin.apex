List<Automobile__c> automobiles = [
    SELECT Id, Name, VIN__c
    FROM Automobile__c
    WHERE VIN__c != null
    LIMIT 10000
];

List<Automobile__c> updates = new List<Automobile__c>();

for (Automobile__c automobile : automobiles) {
    String vinSuffix = ' - ' + automobile.VIN__c;
    if (String.isBlank(automobile.Name) || automobile.Name.endsWith(vinSuffix)) {
        continue;
    }

    updates.add(new Automobile__c(
        Id = automobile.Id,
        Name = automobile.Name + vinSuffix
    ));
}

Database.SaveResult[] results = Database.update(updates, false);
Integer updated = 0;
Integer failed = 0;

for (Database.SaveResult result : results) {
    if (result.isSuccess()) {
        updated++;
    } else {
        failed++;
        for (Database.Error err : result.getErrors()) {
            System.debug('Failed to update Automobile__c name: ' + err.getMessage());
        }
    }
}

System.debug('Automobile name backfill complete. Evaluated: ' + automobiles.size() + ', Updated: ' + updated + ', Failed: ' + failed);