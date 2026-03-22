public with sharing class InventoryAtLocationController {
    public class FlowRequest {
        @InvocableVariable
        public String context;
    }

    public class FlowResult {
        @InvocableVariable
        public Integer locationsProcessed;

        @InvocableVariable
        public Integer totalVehicles;
    }

    public class LocationInventoryRow {
        @AuraEnabled public Id locationId;
        @AuraEnabled public String locationName;
        @AuraEnabled public Integer vehicleCount;

        public LocationInventoryRow(Id locationId, String locationName, Integer vehicleCount) {
            this.locationId = locationId;
            this.locationName = locationName;
            this.vehicleCount = vehicleCount;
        }
    }

    @AuraEnabled
    public static List<LocationInventoryRow> getVehicleCountByLocation() {
        Map<String, Schema.SObjectField> locationFields = Schema.SObjectType.Location.fields.getMap();
        if (!locationFields.containsKey('Number_of_vehicles__c')) {
            throw new AuraHandledException('Location.Number_of_vehicles__c field was not found.');
        }

        Map<String, Schema.SObjectField> automobileFields = Schema.SObjectType.Automobile__c.fields.getMap();
        Map<String, Schema.RecordTypeInfo> automobileRecordTypes = Schema.SObjectType.Automobile__c.getRecordTypeInfosByDeveloperName();
        Id soldRecordTypeId = automobileRecordTypes.containsKey('Sold')
            ? automobileRecordTypes.get('Sold').getRecordTypeId()
            : null;

        Map<Id, Integer> vehicleCountByLocation = new Map<Id, Integer>();

        String automobileWhereClause = 'Location__c != NULL';
        if (soldRecordTypeId != null) {
            automobileWhereClause += ' AND RecordTypeId != \'' + String.escapeSingleQuotes(String.valueOf(soldRecordTypeId)) + '\'';
        }
        if (automobileFields.containsKey('Status__c')) {
            automobileWhereClause += ' AND (Status__c = NULL OR Status__c != \'Sold\')';
        }

        for (AggregateResult ar : Database.query(
            'SELECT Location__c locId, COUNT(Id) vehicleCount ' +
            'FROM Automobile__c ' +
            'WHERE ' + automobileWhereClause + ' ' +
            'GROUP BY Location__c'
        )) {
            vehicleCountByLocation.put(
                (Id) ar.get('locId'),
                Integer.valueOf(String.valueOf(ar.get('vehicleCount')))
            );
        }

        List<SObject> locationsToUpdate = new List<SObject>();
        Schema.SObjectType locationType = Schema.getGlobalDescribe().get('Location');
        for (SObject loc : Database.query('SELECT Id, Name, Number_of_vehicles__c FROM Location')) {
            Id locId = (Id) loc.get('Id');
            Integer computedCount = vehicleCountByLocation.containsKey(locId)
                ? vehicleCountByLocation.get(locId)
                : 0;
            Decimal currentCount = (Decimal) loc.get('Number_of_vehicles__c');
            if (currentCount == null) {
                currentCount = Decimal.valueOf(0);
            }
            if (currentCount != Decimal.valueOf(computedCount)) {
                SObject locUpdate = locationType.newSObject(locId);
                locUpdate.put('Number_of_vehicles__c', Decimal.valueOf(computedCount));
                locationsToUpdate.add(locUpdate);
            }
        }

        if (!locationsToUpdate.isEmpty()) {
            Database.update(locationsToUpdate, false);
        }

        List<LocationInventoryRow> rows = new List<LocationInventoryRow>();
        for (SObject loc : Database.query(
            'SELECT Id, Name, Number_of_vehicles__c ' +
            'FROM Location ' +
            'ORDER BY Number_of_vehicles__c DESC, Name ASC'
        )) {
            Decimal countValue = (Decimal) loc.get('Number_of_vehicles__c');
            Integer vehicleCount = countValue == null
                ? 0
                : Integer.valueOf(String.valueOf(countValue));
            rows.add(new LocationInventoryRow((Id) loc.get('Id'), (String) loc.get('Name'), vehicleCount));
        }

        return rows;
    }

    @InvocableMethod(label='Refresh Vehicle Counts on Locations' description='Counts Automobile records by Location and writes to Location.Number_of_vehicles__c.')
    public static List<FlowResult> refreshVehicleCountsForFlow(List<FlowRequest> requests) {
        List<LocationInventoryRow> rows = getVehicleCountByLocation();
        Integer total = 0;
        for (LocationInventoryRow row : rows) {
            total += row.vehicleCount;
        }

        FlowResult result = new FlowResult();
        result.locationsProcessed = rows.size();
        result.totalVehicles = total;
        return new List<FlowResult>{ result };
    }
}
