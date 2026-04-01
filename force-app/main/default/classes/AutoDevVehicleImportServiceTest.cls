@IsTest
private class AutoDevVehicleImportServiceTest {
    @TestVisible private static String mockMakeValue;
    @TestVisible private static String mockColorValue;
    @TestVisible private static String mockYearValue;
    @TestVisible private static String existingVinValue;
    @TestVisible private static String newVinValue;

    private class AutoDevListingsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            System.assertEquals('GET', request.getMethod());
            System.assert(request.getEndpoint().contains('https://api.auto.dev/listings?page=1&limit=25'));
            System.assertEquals('Bearer test-api-key', request.getHeader('Authorization'));
            System.assert(request.getEndpoint().contains('retailListing.state=PA'));

            String safeMake = String.isBlank(mockMakeValue) ? 'Ford' : mockMakeValue;
            String safeColor = String.isBlank(mockColorValue) ? 'Black' : mockColorValue;
            String safeYear = String.isBlank(mockYearValue) ? String.valueOf(System.today().year()) : mockYearValue;

            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"data":[' +
                '{"vin":"' + existingVinValue + '","vehicle":{"vin":"' + existingVinValue + '","year":' + safeYear + ',"make":"' + safeMake + '","model":"F-150","exteriorColor":"' + safeColor + '"},"retailListing":{"price":42000,"miles":10,"used":false,"state":"PA"}},' +
                '{"vin":"' + newVinValue + '","vehicle":{"vin":"' + newVinValue + '","year":' + safeYear + ',"make":"' + safeMake + '","model":"Camry","exteriorColor":"' + safeColor + '"},"retailListing":{"price":31000,"miles":12000,"used":true,"state":"PA"}},' +
                '{"vin":"","vehicle":{"make":"Chevrolet","model":"Equinox"},"retailListing":{"price":28000,"miles":120,"used":false,"state":"PA"}}' +
            ']}');
            return response;
        }
    }

    private static String makeVin(String seed) {
        String chars = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789';
        String out = '';
        Integer hash = Math.abs(seed.hashCode());

        for (Integer i = 0; i < 17; i++) {
            Integer idx = Math.mod(hash + (i * 17), chars.length());
            out += chars.substring(idx, idx + 1);
        }

        return out;
    }

    private static String makeSeed(String suffix) {
        return String.valueOf(System.now().getTime()) + '-' + String.valueOf(Math.abs(Crypto.getRandomInteger())) + '-' + suffix;
    }

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
    static void importsListingsAndSkipsExistingVin() {
        mockMakeValue = getAllowedPicklistValue('Make__c', 'Ford');
        mockColorValue = getAllowedPicklistValue('Color__c', 'Black');
        mockYearValue = getAllowedPicklistValue('Year__c', String.valueOf(System.today().year()));
        existingVinValue = makeVin(makeSeed('EXISTING'));
        newVinValue = makeVin(makeSeed('NEW'));

        insert new Automobile__c(
            Name = 'Existing Vehicle - ' + existingVinValue,
            VIN__c = existingVinValue
        );

        insert new Schema.Location(
            Name = 'Pennsylvania Import Hub',
            State__c = 'PA'
        );

        AutoDevVehicleImportService.apiKeyOverride = 'test-api-key';
        AutoDevVehicleImportService.stateFilterOverride = 'PA';

        Test.setMock(HttpCalloutMock.class, new AutoDevListingsMock());

        Test.startTest();
        AutoDevVehicleImportService.ImportResult result = AutoDevVehicleImportService.importNightlyListings();
        Test.stopTest();

        System.assertEquals(25, result.requested);
        System.assertEquals(1, result.imported);
        System.assertEquals(1, result.skippedExisting);
        System.assertEquals(1, result.skippedMissingVin);
        System.assertEquals(0, result.failed);

        Automobile__c insertedAuto = [
            SELECT Name, VIN__c, Make__c, Mileage__c, Value__c, Bought_Via__c, Bought_Price__c
            FROM Automobile__c
            WHERE VIN__c = :newVinValue
            LIMIT 1
        ];

        System.assertEquals(mockMakeValue + ' Camry - ' + newVinValue, insertedAuto.Name);
        System.assertEquals(mockMakeValue, insertedAuto.Make__c);
        System.assertEquals(12000, insertedAuto.Mileage__c);
        System.assertEquals(31000, insertedAuto.Value__c);
        System.assertEquals(Decimal.valueOf('26350.00'), insertedAuto.Bought_Price__c);
        System.assertEquals('Auto.dev', insertedAuto.Bought_Via__c);
    }

    @IsTest
    static void schedulesNightlyJob() {
        mockMakeValue = getAllowedPicklistValue('Make__c', 'Ford');
        mockColorValue = getAllowedPicklistValue('Color__c', 'Black');
        mockYearValue = getAllowedPicklistValue('Year__c', String.valueOf(System.today().year()));
        existingVinValue = makeVin(makeSeed('EXISTING'));
        newVinValue = makeVin(makeSeed('NEW'));

        AutoDevVehicleImportService.apiKeyOverride = 'test-api-key';
        AutoDevVehicleImportService.stateFilterOverride = 'PA';
        Test.setMock(HttpCalloutMock.class, new AutoDevListingsMock());

        Test.startTest();
        String jobId = AutoDevNightlyImportScheduler.scheduleNightly();
        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }
}