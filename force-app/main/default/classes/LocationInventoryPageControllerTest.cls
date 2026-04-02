@IsTest
private class LocationInventoryPageControllerTest {
    private static String getAllowedPicklistValue(String fieldName, String preferredValue) {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Automobile__c.fields.getMap();
        if (!fieldMap.containsKey(fieldName)) {
            return preferredValue;
        }

        String firstValue;
        for (Schema.PicklistEntry entry : fieldMap.get(fieldName).getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            String value = entry.getValue();
            if (firstValue == null) {
                firstValue = value;
            }
            if (value == preferredValue) {
                return value;
            }
        }

        return firstValue;
    }

    @IsTest
    static void returnsCurrentAndSoldInventoryByLocation() {
        Schema.Location locationRecord = new Schema.Location(
            Name = 'Test Location',
            LocationType = 'Site',
            IsInventoryLocation = true,
            Latitude = 42.0,
            Longitude = -71.0
        );
        insert locationRecord;

        String makeValue = getAllowedPicklistValue('Make__c', 'Ford');
        String yearValue = getAllowedPicklistValue('Year__c', String.valueOf(System.today().year()));

        Automobile__c currentAuto = new Automobile__c(
            Name = 'Current Test Car',
            Location__c = locationRecord.Id,
            Make__c = makeValue,
            Year__c = yearValue,
            Mileage__c = 10000,
            Value__c = 25000,
            Bought__c = System.today().addDays(-15)
        );

        Automobile__c soldAuto = new Automobile__c(
            Name = 'Sold Test Car',
            Location__c = locationRecord.Id,
            Make__c = makeValue,
            Year__c = yearValue,
            Mileage__c = 22000,
            Value__c = 19000,
            Bought__c = System.today().addDays(-30),
            Sold__c = System.today().addDays(-1)
        );
        insert new List<Automobile__c>{ currentAuto, soldAuto };

        Test.startTest();
        LocationInventoryPageController.InventoryData result =
            LocationInventoryPageController.getLocationInventory(locationRecord.Id);
        Test.stopTest();

        System.assertEquals('Test Location', result.locationName);
        System.assertEquals(1, result.currentInventory.size());
        System.assertEquals(1, result.soldInventory.size());
        System.assertEquals('Current Test Car', result.currentInventory[0].name);
        System.assertEquals('Sold Test Car', result.soldInventory[0].name);
    }
}
