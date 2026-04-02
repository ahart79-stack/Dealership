public with sharing class CreateFranchiseActionController {
    @AuraEnabled(cacheable=true)
    public static List<LocationOption> getLocations() {
        List<LocationOption> options = new List<LocationOption>();
        for (Schema.Location loc : [SELECT Id, Name FROM Location ORDER BY Name LIMIT 500]) {
            options.add(new LocationOption(loc.Name, loc.Id));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<FranchiseOption> getFranchises() {
        List<FranchiseOption> options = new List<FranchiseOption>();
        for (SObject franchise : Database.query('SELECT Id, Name FROM Franchise__c ORDER BY Name LIMIT 500')) {
            options.add(new FranchiseOption((String) franchise.get('Name'), (String) franchise.get('Id')));
        }
        return options;
    }

    @AuraEnabled
    public static Id upsertFranchise(String mode, Id franchiseId, String franchiseName, List<Id> locationIds) {
        if (String.isBlank(mode) || mode == 'create') {
            return createFranchise(franchiseName, locationIds);
        }
        if (mode != 'update') {
            throw new FranchiseActionException('Unsupported mode: ' + mode);
        }
        return updateFranchise(franchiseId, franchiseName, locationIds);
    }

    @AuraEnabled
    public static Id createFranchise(String franchiseName, List<Id> locationIds) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey('Franchise__c')) {
            throw new FranchiseActionException('Franchise__c object was not found in this org.');
        }

        Schema.SObjectType franchiseType = globalDescribe.get('Franchise__c');
        Map<String, Schema.SObjectField> franchiseFields = franchiseType.getDescribe().fields.getMap();

        SObject franchiseRecord = franchiseType.newSObject();
        if (franchiseFields.containsKey('Name') && franchiseFields.get('Name').getDescribe().isCreateable()) {
            if (String.isBlank(franchiseName)) {
                throw new FranchiseActionException('Franchise Name is required.');
            }
            franchiseRecord.put('Name', franchiseName.trim());
        }

        insert franchiseRecord;
        Id franchiseId = (Id) franchiseRecord.get('Id');

        if (locationIds == null || locationIds.isEmpty()) {
            return franchiseId;
        }

        relateLocationsToFranchise(franchiseId, locationIds, globalDescribe);
        return franchiseId;
    }

    private static Id updateFranchise(Id franchiseId, String franchiseName, List<Id> locationIds) {
        if (franchiseId == null) {
            throw new FranchiseActionException('Select an existing Franchise to update.');
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Schema.SObjectType franchiseType = globalDescribe.get('Franchise__c');
        Map<String, Schema.SObjectField> franchiseFields = franchiseType.getDescribe().fields.getMap();

        if (!String.isBlank(franchiseName) && franchiseFields.containsKey('Name')) {
            SObject franchiseUpdate = franchiseType.newSObject(franchiseId);
            franchiseUpdate.put('Name', franchiseName.trim());
            update franchiseUpdate;
        }

        if (locationIds != null && !locationIds.isEmpty()) {
            relateLocationsToFranchise(franchiseId, locationIds, globalDescribe);
        }
        return franchiseId;
    }

    private static void relateLocationsToFranchise(Id franchiseId, List<Id> locationIds, Map<String, Schema.SObjectType> globalDescribe) {
        Map<String, Schema.SObjectField> locationFields = Schema.SObjectType.Location.fields.getMap();
        String locationFranchiseField = findReferenceFieldToTarget(locationFields, 'Franchise__c');
        if (locationFranchiseField != null) {
            List<Schema.Location> locationsToUpdate = [
                SELECT Id
                FROM Location
                WHERE Id IN :locationIds
                LIMIT 500
            ];
            for (Schema.Location loc : locationsToUpdate) {
                loc.put(locationFranchiseField, franchiseId);
            }
            update locationsToUpdate;
            return;
        }

        // Fallback if a junction object is used instead of a direct Location lookup.
        JunctionMapping mapping = findJunctionMapping(globalDescribe);
        if (mapping != null) {
            List<SObject> junctionRecords = new List<SObject>();
            for (Id locationId : locationIds) {
                SObject junction = mapping.sobjectType.newSObject();
                junction.put(mapping.franchiseFieldApiName, franchiseId);
                junction.put(mapping.locationFieldApiName, locationId);
                junctionRecords.add(junction);
            }
            insert junctionRecords;
            return;
        }

        throw new FranchiseActionException('No Franchise relationship path was found. Add a lookup from Location to Franchise__c or create a junction object with lookup fields to both Franchise__c and Location.');
    }

    private static String findReferenceFieldToTarget(
        Map<String, Schema.SObjectField> fieldMap,
        String targetObjectSuffix
    ) {
        for (String fieldApiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldApiName).getDescribe();
            if (fieldDescribe.getType() != Schema.DisplayType.Reference) {
                continue;
            }
            for (Schema.SObjectType referenceType : fieldDescribe.getReferenceTo()) {
                String referencedObjectName = referenceType.getDescribe().getName();
                if (referencedObjectName == targetObjectSuffix || referencedObjectName.endsWith('__' + targetObjectSuffix)) {
                    return fieldApiName;
                }
            }
        }
        return null;
    }

    private static JunctionMapping findJunctionMapping(Map<String, Schema.SObjectType> globalDescribe) {
        for (String objectApiName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult describeResult = globalDescribe.get(objectApiName).getDescribe();
            if (!describeResult.isCreateable() || !describeResult.isCustom() || !objectApiName.endsWith('__c')) {
                continue;
            }
            String normalizedName = objectApiName.toLowerCase();
            if (!normalizedName.contains('franchise') && !normalizedName.contains('location')) {
                continue;
            }

            Map<String, Schema.SObjectField> fields = describeResult.fields.getMap();
            String franchiseField = findReferenceFieldToTarget(fields, 'Franchise__c');
            String locationField = findReferenceFieldToTarget(fields, 'Location');
            if (franchiseField == null || locationField == null) {
                continue;
            }

            Schema.DescribeFieldResult franchiseFieldDescribe = fields.get(franchiseField).getDescribe();
            Schema.DescribeFieldResult locationFieldDescribe = fields.get(locationField).getDescribe();
            if (!franchiseFieldDescribe.isCreateable() || !locationFieldDescribe.isCreateable()) {
                continue;
            }

            // Skip objects that require additional mandatory fields beyond relationship fields.
            if (hasAdditionalRequiredFields(fields, new Set<String>{franchiseField, locationField})) {
                continue;
            }

            JunctionMapping mapping = new JunctionMapping();
            mapping.sobjectType = globalDescribe.get(objectApiName);
            mapping.franchiseFieldApiName = franchiseField;
            mapping.locationFieldApiName = locationField;
            return mapping;
        }
        return null;
    }

    private static Boolean hasAdditionalRequiredFields(
        Map<String, Schema.SObjectField> fields,
        Set<String> allowedRequiredFields
    ) {
        for (String fieldApiName : fields.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fields.get(fieldApiName).getDescribe();
            if (!fieldDescribe.isCreateable()) {
                continue;
            }
            if (fieldDescribe.isNillable() || fieldDescribe.isDefaultedOnCreate()) {
                continue;
            }
            // Name can be required for text-name objects; allow it.
            if (fieldApiName == 'Name') {
                continue;
            }
            if (!allowedRequiredFields.contains(fieldApiName)) {
                return true;
            }
        }
        return false;
    }

    private class JunctionMapping {
        public Schema.SObjectType sobjectType;
        public String franchiseFieldApiName;
        public String locationFieldApiName;
    }

    public class FranchiseActionException extends Exception {}

    public class LocationOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public LocationOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class FranchiseOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public FranchiseOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}
