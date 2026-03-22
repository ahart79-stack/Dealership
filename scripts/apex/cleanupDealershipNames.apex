List<typeofdealership__c> legacy = [
    SELECT Id, Name
    FROM typeofdealership__c
    WHERE Name LIKE '% Dealership'
];

Map<String, Id> plainNameToId = new Map<String, Id>();
Set<String> baseNames = new Set<String>();
for (typeofdealership__c d : legacy) {
    String base = d.Name.endsWith(' Dealership')
        ? d.Name.substring(0, d.Name.length() - ' Dealership'.length())
        : d.Name;
    baseNames.add(base);
}

for (typeofdealership__c d : [
    SELECT Id, Name
    FROM typeofdealership__c
    WHERE Name IN :baseNames
]) {
    plainNameToId.put(d.Name, d.Id);
}

Map<Id, Id> legacyToTarget = new Map<Id, Id>();
List<typeofdealership__c> renameList = new List<typeofdealership__c>();
for (typeofdealership__c d : legacy) {
    String base = d.Name.endsWith(' Dealership')
        ? d.Name.substring(0, d.Name.length() - ' Dealership'.length())
        : d.Name;
    if (plainNameToId.containsKey(base) && plainNameToId.get(base) != d.Id) {
        legacyToTarget.put(d.Id, plainNameToId.get(base));
    } else {
        d.Name = base;
        renameList.add(d);
    }
}

Integer autosRepointed = 0;
if (!legacyToTarget.isEmpty()) {
    List<Automobile__c> autos = [
        SELECT Id, Type_of_Dealership__c
        FROM Automobile__c
        WHERE Type_of_Dealership__c IN :legacyToTarget.keySet()
        LIMIT 50000
    ];
    for (Automobile__c a : autos) {
        Id targetId = legacyToTarget.get(a.Type_of_Dealership__c);
        if (targetId != null) {
            a.Type_of_Dealership__c = targetId;
            autosRepointed++;
        }
    }
    if (!autos.isEmpty()) {
        update autos;
    }
}

Integer renamed = 0;
if (!renameList.isEmpty()) {
    update renameList;
    renamed = renameList.size();
}

Integer deleted = 0;
if (!legacyToTarget.isEmpty()) {
    List<typeofdealership__c> toDelete = new List<typeofdealership__c>();
    for (Id legacyId : legacyToTarget.keySet()) {
        toDelete.add(new typeofdealership__c(Id = legacyId));
    }
    delete toDelete;
    deleted = toDelete.size();
}

System.debug(
    'Dealership cleanup complete. Legacy found=' + legacy.size() +
    ', renamed=' + renamed +
    ', repointedAutos=' + autosRepointed +
    ', deletedLegacyDuplicates=' + deleted
);
