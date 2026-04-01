@IsTest
private class SellAutomobileControllerTest {
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

    private static List<Schema.Location> createLocations(Integer count) {
        List<Schema.Location> locations = new List<Schema.Location>();
        for (Integer i = 0; i < count; i++) {
            Schema.Location locationRow = new Schema.Location();
            locationRow.Name = 'Nightly Sales Test Location ' + i;
            locationRow.LocationType = 'Site';
            locationRow.IsInventoryLocation = true;
            locations.add(locationRow);
        }
        insert locations;
        return locations;
    }

    private static String firstExisting(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        for (String fieldName : candidates) {
            if (fieldMap.containsKey(fieldName)) {
                return fieldName;
            }
        }
        return null;
    }

    private static String normalizeFieldLabel(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        return input.replaceAll('[^A-Za-z0-9]', '').toLowerCase();
    }

    private static String resolveContactRollupField(
        Map<String, Schema.SObjectField> fieldMap,
        List<String> apiCandidates,
        String labelCandidate
    ) {
        String byApi = firstExisting(fieldMap, apiCandidates);
        if (byApi != null) {
            return byApi;
        }

        String normalizedLabel = normalizeFieldLabel(labelCandidate);
        for (String fieldName : fieldMap.keySet()) {
            String fieldLabel = fieldMap.get(fieldName).getDescribe().getLabel();
            if (normalizeFieldLabel(fieldLabel) == normalizedLabel) {
                return fieldName;
            }
        }

        return null;
    }

    private static Set<Id> createInventory(List<Schema.Location> locations, Integer autosPerLocation) {
        String makeValue = getAllowedPicklistValue('Make__c', 'Ford');
        String yearValue = getAllowedPicklistValue('Year__c', String.valueOf(System.today().year()));
        List<Automobile__c> automobiles = new List<Automobile__c>();

        Integer counter = 0;
        for (Schema.Location locationRow : locations) {
            for (Integer i = 0; i < autosPerLocation; i++) {
                automobiles.add(new Automobile__c(
                    Name = 'Nightly Sales Test Auto ' + counter,
                    VIN__c = 'VINTEST000000' + String.valueOf(1000 + counter),
                    Bought__c = System.today().addDays(-10 - counter),
                    Value__c = 25000,
                    Bought_Price__c = 22000,
                    Make__c = makeValue,
                    Year__c = yearValue,
                    Location__c = locationRow.Id
                ));
                counter++;
            }
        }

        insert automobiles;

        Set<Id> automobileIds = new Set<Id>();
        for (Automobile__c auto : automobiles) {
            automobileIds.add(auto.Id);
        }
        return automobileIds;
    }

    @IsTest
    static void sellNightlyAutosSpreadsAcrossLocations() {
        insert new Contact(LastName = 'Nightly Buyer');
        List<Schema.Location> locations = createLocations(4);
        Set<Id> automobileIds = createInventory(locations, 1);

        SellAutomobileController.nightlyMinOverride = 4;
        SellAutomobileController.nightlyMaxOverride = 4;

        Test.startTest();
        Integer soldCount = SellAutomobileController.sellNightlyAutos();
        Test.stopTest();

        SellAutomobileController.nightlyMinOverride = null;
        SellAutomobileController.nightlyMaxOverride = null;

        System.assertEquals(4, soldCount);

        List<Automobile__c> soldAutos = [
            SELECT Id, Location__c, Buyer__c
            FROM Automobile__c
            WHERE Id IN :automobileIds AND Buyer__c != null
        ];
        System.assertEquals(4, soldAutos.size());

        Set<Id> soldLocationIds = new Set<Id>();
        for (Automobile__c auto : soldAutos) {
            soldLocationIds.add(auto.Location__c);
            System.assertNotEquals(null, auto.Buyer__c);
        }
        System.assertEquals(4, soldLocationIds.size());
    }

    @IsTest
    static void sellRandomAutosManualPath() {
        insert new Contact(LastName = 'Manual Buyer');
        List<Schema.Location> locations = createLocations(2);
        createInventory(locations, 3);

        Test.startTest();
        Integer soldCount = SellAutomobileController.sellRandomAutos(3);
        Test.stopTest();

        System.assert(soldCount >= 1, 'Expected at least 1 car sold via manual path');

        List<Automobile__c> soldAutos = [
            SELECT Id, Sold__c
            FROM Automobile__c
            WHERE Buyer__c != null
            LIMIT 10
        ];
        for (Automobile__c auto : soldAutos) {
            System.assertEquals(System.today(), auto.Sold__c, 'Sold__c should always be today');
        }
    }

    @IsTest
    static void schedulesNightlyAutomobileSalesJob() {
        SellAutomobileController.nightlyMinOverride = 1;
        SellAutomobileController.nightlyMaxOverride = 1;

        Test.startTest();
        String jobId = NightlyAutomobileSalesScheduler.scheduleNightly();
        Test.stopTest();

        SellAutomobileController.nightlyMinOverride = null;
        SellAutomobileController.nightlyMaxOverride = null;

        System.assertNotEquals(null, jobId);
    }

    @IsTest
    static void updatesContactPurchaseRollupsFromPurchases() {
        Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();
        String totalAmountField = resolveContactRollupField(
            contactFieldMap,
            new List<String>{
                'Total_Amount_Purchased__c',
                'TotalAmountPurchased__c',
                'Total_amount_purchased__c'
            },
            'Total amount purchased'
        );
        String purchaseCountField = resolveContactRollupField(
            contactFieldMap,
            new List<String>{
                'Number_of_Purchases__c',
                'NumberOfPurchases__c',
                'Number_of_purchases__c'
            },
            'Number of Purchases'
        );

        if (totalAmountField == null && purchaseCountField == null) {
            return;
        }

        Contact buyer = new Contact(LastName = 'Rollup Buyer');
        insert buyer;

        List<Schema.Location> locations = createLocations(1);
        createInventory(locations, 3);

        Test.startTest();
        Integer soldCount = SellAutomobileController.sellRandomAutos(3);
        Test.stopTest();

        System.assert(soldCount >= 1, 'Expected sold automobiles for rollup validation.');

        AggregateResult aggregateRow = [
            SELECT COUNT(Id) purchaseCount, SUM(Purchase_Price__c) totalAmount
            FROM Purchase__c
            WHERE Contact__c = :buyer.Id
        ];

        Integer expectedCount = Integer.valueOf(String.valueOf(aggregateRow.get('purchaseCount')));
        Decimal expectedTotal = aggregateRow.get('totalAmount') == null
            ? Decimal.valueOf(0)
            : ((Decimal) aggregateRow.get('totalAmount')).setScale(2);

        String soql = 'SELECT Id';
        if (totalAmountField != null) {
            soql += ', ' + totalAmountField;
        }
        if (purchaseCountField != null) {
            soql += ', ' + purchaseCountField;
        }
        soql += ' FROM Contact WHERE Id = :buyer.Id';
        Contact refreshedBuyer = Database.query(soql);

        if (purchaseCountField != null) {
            Integer actualCount = refreshedBuyer.get(purchaseCountField) == null
                ? 0
                : Integer.valueOf(String.valueOf(refreshedBuyer.get(purchaseCountField)));
            System.assertEquals(expectedCount, actualCount, 'Purchase count rollup should match Purchase__c count.');
        }
        if (totalAmountField != null) {
            Decimal actualTotal = refreshedBuyer.get(totalAmountField) == null
                ? Decimal.valueOf(0)
                : Decimal.valueOf(String.valueOf(refreshedBuyer.get(totalAmountField))).setScale(2);
            System.assertEquals(expectedTotal, actualTotal, 'Total purchased rollup should match Purchase__c sum.');
        }
    }
}