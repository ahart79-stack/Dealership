// Deduplicate contacts: keep the oldest per first+last name,
// reroute all Purchase__c and Automobile__c references, then delete extras.

// ── Step 1: bucket all contacts by full name ──────────────────────────────
Map<String, List<Contact>> byName = new Map<String, List<Contact>>();
for (Contact c : [SELECT Id, FirstName, LastName, CreatedDate FROM Contact ORDER BY CreatedDate ASC]) {
    String key = (c.FirstName == null ? '' : c.FirstName) + '|' + (c.LastName == null ? '' : c.LastName);
    if (!byName.containsKey(key)) {
        byName.put(key, new List<Contact>());
    }
    byName.get(key).add(c);
}

// ── Step 2: separate keepers from duplicates ─────────────────────────────
Map<Id, Id> dupeToKeeper = new Map<Id, Id>(); // dupeId -> keeperId
Set<Id> dupeIds = new Set<Id>();

for (String key : byName.keySet()) {
    List<Contact> grp = byName.get(key);
    if (grp.size() <= 1) continue;
    Id keeperId = grp[0].Id; // oldest first (sorted above)
    for (Integer i = 1; i < grp.size(); i++) {
        dupeToKeeper.put(grp[i].Id, keeperId);
        dupeIds.add(grp[i].Id);
    }
}

System.debug('Duplicate contacts to remove: ' + dupeIds.size());

// ── Step 3: re-point Purchase__c.Contact__c ─────────────────────────────
List<Purchase__c> purchasesToUpdate = new List<Purchase__c>();
for (Purchase__c p : [SELECT Id, Contact__c FROM Purchase__c WHERE Contact__c IN :dupeIds]) {
    purchasesToUpdate.add(new Purchase__c(Id = p.Id, Contact__c = dupeToKeeper.get(p.Contact__c)));
}
if (!purchasesToUpdate.isEmpty()) {
    Database.update(purchasesToUpdate, false);
    System.debug('Purchases re-pointed: ' + purchasesToUpdate.size());
}

// ── Step 4: re-point Automobile__c.Buyer__c ─────────────────────────────
List<Automobile__c> autosToUpdate = new List<Automobile__c>();
for (Automobile__c a : [SELECT Id, Buyer__c FROM Automobile__c WHERE Buyer__c IN :dupeIds]) {
    autosToUpdate.add(new Automobile__c(Id = a.Id, Buyer__c = dupeToKeeper.get(a.Buyer__c)));
}
if (!autosToUpdate.isEmpty()) {
    Database.update(autosToUpdate, false);
    System.debug('Automobiles re-pointed: ' + autosToUpdate.size());
}

// ── Step 5: delete the duplicates ────────────────────────────────────────
List<Contact> dupesToDelete = new List<Contact>();
for (Id dupeId : dupeIds) {
    dupesToDelete.add(new Contact(Id = dupeId));
}

Integer deleted = 0;
Integer failed = 0;
if (!dupesToDelete.isEmpty()) {
    Database.DeleteResult[] results = Database.delete(dupesToDelete, false);
    for (Database.DeleteResult dr : results) {
        if (dr.isSuccess()) { deleted++; } else {
            failed++;
            for (Database.Error e : dr.getErrors()) {
                System.debug('Delete error: ' + e.getMessage());
            }
        }
    }
}

System.debug('Dedup complete. Deleted: ' + deleted + ', Failed: ' + failed);
