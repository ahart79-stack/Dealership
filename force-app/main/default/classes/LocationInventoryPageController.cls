public with sharing class LocationInventoryPageController {
    public class AutomobileRow {
        @AuraEnabled public Id automobileId;
        @AuraEnabled public String name;
        @AuraEnabled public String make;
        @AuraEnabled public String year;
        @AuraEnabled public Decimal mileage;
        @AuraEnabled public Decimal value;
        @AuraEnabled public String status;
        @AuraEnabled public Date soldDate;

        public AutomobileRow(Automobile__c automobileRecord, Map<String, Schema.SObjectField> fieldMap) {
            automobileId = automobileRecord.Id;
            name = automobileRecord.Name;
            make = fieldMap.containsKey('Make__c') ? (String) automobileRecord.get('Make__c') : null;
            year = fieldMap.containsKey('Year__c') ? (String) automobileRecord.get('Year__c') : null;
            mileage = fieldMap.containsKey('Mileage__c') ? (Decimal) automobileRecord.get('Mileage__c') : null;
            value = fieldMap.containsKey('Value__c') ? (Decimal) automobileRecord.get('Value__c') : null;
            status = fieldMap.containsKey('Status__c') ? (String) automobileRecord.get('Status__c') : null;
            soldDate = extractSoldDate(automobileRecord, fieldMap);
        }
    }

    public class InventoryData {
        @AuraEnabled public String locationName;
        @AuraEnabled public List<AutomobileRow> currentInventory;
        @AuraEnabled public List<AutomobileRow> soldInventory;

        public InventoryData() {
            currentInventory = new List<AutomobileRow>();
            soldInventory = new List<AutomobileRow>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static InventoryData getLocationInventory(Id locationId) {
        if (locationId == null) {
            throw new AuraHandledException('Location Id is required.');
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Automobile__c.fields.getMap();

        String soql = 'SELECT Id, Name, RecordType.DeveloperName';
        if (fieldMap.containsKey('Make__c')) {
            soql += ', Make__c';
        }
        if (fieldMap.containsKey('Year__c')) {
            soql += ', Year__c';
        }
        if (fieldMap.containsKey('Mileage__c')) {
            soql += ', Mileage__c';
        }
        if (fieldMap.containsKey('Value__c')) {
            soql += ', Value__c';
        }
        if (fieldMap.containsKey('Status__c')) {
            soql += ', Status__c';
        }
        if (fieldMap.containsKey('Sold__c')) {
            soql += ', Sold__c';
        }
        if (fieldMap.containsKey('Sold_Date__c')) {
            soql += ', Sold_Date__c';
        }
        if (fieldMap.containsKey('Date_Sold__c')) {
            soql += ', Date_Sold__c';
        }
        if (fieldMap.containsKey('SoldOn__c')) {
            soql += ', SoldOn__c';
        }
        if (fieldMap.containsKey('Sold_DateTime__c')) {
            soql += ', Sold_DateTime__c';
        }

        soql += ' FROM Automobile__c WHERE Location__c = :locationId ORDER BY CreatedDate DESC LIMIT 500';

        InventoryData output = new InventoryData();
        Schema.Location locationRecord = [SELECT Id, Name FROM Location WHERE Id = :locationId LIMIT 1];
        output.locationName = locationRecord.Name;

        for (Automobile__c automobileRecord : Database.query(soql)) {
            AutomobileRow row = new AutomobileRow(automobileRecord, fieldMap);
            if (isSold(automobileRecord, fieldMap)) {
                output.soldInventory.add(row);
            } else {
                output.currentInventory.add(row);
            }
        }

        return output;
    }

    private static Boolean isSold(Automobile__c automobileRecord, Map<String, Schema.SObjectField> fieldMap) {
        if (automobileRecord.RecordType != null && automobileRecord.RecordType.DeveloperName == 'Sold') {
            return true;
        }

        if (fieldMap.containsKey('Status__c')) {
            String statusValue = (String) automobileRecord.get('Status__c');
            if (!String.isBlank(statusValue) && statusValue.trim().toLowerCase() == 'sold') {
                return true;
            }
        }

        if (fieldMap.containsKey('Sold__c')) {
            Object soldValue = automobileRecord.get('Sold__c');
            if (soldValue == null) {
                return false;
            }

            Schema.DisplayType soldType = fieldMap.get('Sold__c').getDescribe().getType();
            if (soldType == Schema.DisplayType.Boolean) {
                return (Boolean) soldValue;
            }
            if (soldType == Schema.DisplayType.Date || soldType == Schema.DisplayType.DateTime) {
                return true;
            }
            if (soldType == Schema.DisplayType.Picklist || soldType == Schema.DisplayType.String) {
                return String.valueOf(soldValue).trim().toLowerCase() == 'sold';
            }
            return true;
        }

        return extractSoldDate(automobileRecord, fieldMap) != null;
    }

    private static Date extractSoldDate(Automobile__c automobileRecord, Map<String, Schema.SObjectField> fieldMap) {
        for (String fieldName : new List<String>{'Sold_Date__c', 'Date_Sold__c', 'SoldOn__c', 'Sold_DateTime__c', 'Sold__c'}) {
            if (!fieldMap.containsKey(fieldName)) {
                continue;
            }

            Object value = automobileRecord.get(fieldName);
            if (value == null) {
                continue;
            }

            Schema.DisplayType fieldType = fieldMap.get(fieldName).getDescribe().getType();
            if (fieldType == Schema.DisplayType.Date) {
                return (Date) value;
            }
            if (fieldType == Schema.DisplayType.DateTime) {
                return ((Datetime) value).date();
            }
        }

        return null;
    }
}
