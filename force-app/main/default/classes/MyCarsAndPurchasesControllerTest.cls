@IsTest
private class MyCarsAndPurchasesControllerTest {
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

    private static String getAllowedCasePicklistValue(String fieldName, String preferredValue) {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
        if (!fieldMap.containsKey(fieldName)) {
            return null;
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
    static void returnsCarsAndPurchasesForCurrentContact() {
        Contact buyer = new Contact(LastName = 'Garage Buyer', Phone = '415-555-0110');
        insert buyer;

        String makeValue = getAllowedPicklistValue('Make__c', 'Ford');
        String yearValue = getAllowedPicklistValue('Year__c', String.valueOf(System.today().year()));

        Automobile__c firstAutomobile = new Automobile__c(
            Name = 'Garage Vehicle 1',
            Buyer__c = buyer.Id,
            Make__c = makeValue,
            Year__c = yearValue,
            Mileage__c = 12000,
            Sales_Price__c = 21000,
            Bought__c = System.today().addDays(-30),
            Sold__c = System.today().addDays(-10)
        );
        Automobile__c secondAutomobile = new Automobile__c(
            Name = 'Garage Vehicle 2',
            Buyer__c = buyer.Id,
            Make__c = makeValue,
            Year__c = yearValue,
            Mileage__c = 8000,
            Sales_Price__c = 25500,
            Bought__c = System.today().addDays(-20),
            Sold__c = System.today().addDays(-5)
        );
        insert new List<Automobile__c>{ firstAutomobile, secondAutomobile };

        insert new List<Purchase__c>{
            new Purchase__c(
                Automobile__c = firstAutomobile.Id,
                Contact__c = buyer.Id,
                Purchased_Date__c = System.today().addDays(-10),
                Purchase_Price__c = 21000
            ),
            new Purchase__c(
                Automobile__c = secondAutomobile.Id,
                Contact__c = buyer.Id,
                Purchased_Date__c = System.today().addDays(-5),
                Purchase_Price__c = 25500
            )
        };

        MyCarsAndPurchasesController.testContactIdOverride = buyer.Id;

        Test.startTest();
        MyCarsAndPurchasesController.DashboardData result =
            MyCarsAndPurchasesController.getMyCarsAndPurchases();
        Test.stopTest();

        MyCarsAndPurchasesController.testContactIdOverride = null;

        System.assertEquals(true, result.hasContact);
        System.assertEquals(buyer.Id, result.contactId);
        System.assertEquals('415-555-0110', result.contactPhone);
        System.assertEquals(2, result.automobileCount);
        System.assertEquals(2, result.purchaseCount);
        System.assertEquals(Decimal.valueOf('46500'), result.totalSpent);
        System.assertEquals(2, result.automobiles.size());
        System.assertEquals(2, result.purchases.size());
        System.assertEquals('Garage Vehicle 2', result.automobiles[0].name);
        System.assertEquals('Garage Vehicle 2', result.purchases[0].automobileName);
    }

    @IsTest
    static void returnsEmptyStateWhenUserHasNoLinkedContact() {
        Test.startTest();
        MyCarsAndPurchasesController.DashboardData result =
            MyCarsAndPurchasesController.getMyCarsAndPurchases();
        Test.stopTest();

        System.assertEquals(false, result.hasContact);
        System.assertEquals(0, result.automobileCount);
        System.assertEquals(0, result.purchaseCount);
        System.assertEquals(Decimal.valueOf(0), result.totalSpent);
        System.assertEquals(0, result.automobiles.size());
        System.assertEquals(0, result.purchases.size());
    }

    @IsTest
    static void submitsServiceRequestForOwnedCar() {
        Account accountRecord = new Account(Name = 'Service Buyer Account');
        insert accountRecord;

        Contact buyer = new Contact(LastName = 'Service Buyer', AccountId = accountRecord.Id);
        insert buyer;

        String makeValue = getAllowedPicklistValue('Make__c', 'Ford');
        String yearValue = getAllowedPicklistValue('Year__c', String.valueOf(System.today().year()));

        Automobile__c automobileRecord = new Automobile__c(
            Name = 'Service Vehicle',
            Buyer__c = buyer.Id,
            Make__c = makeValue,
            Year__c = yearValue,
            Mileage__c = 10000,
            Sales_Price__c = 23000
        );
        insert automobileRecord;

        String caseTypeValue = getAllowedCasePicklistValue('Type', 'Mechanical');
        String caseSubTypeValue = getAllowedCasePicklistValue('Sub_Type__c', 'Brakes');

        MyCarsAndPurchasesController.testContactIdOverride = buyer.Id;

        Test.startTest();
        MyCarsAndPurchasesController.ServiceRequestResult result =
            MyCarsAndPurchasesController.submitDetailedServiceRequest(
                automobileRecord.Id,
                'Brake noise when turning',
                caseTypeValue,
                caseSubTypeValue,
                45876,
                String.valueOf(System.today().addDays(7)),
                '10:30',
                '415-555-0182',
                'Noise is louder after driving for 20 minutes.'
            );
        Test.stopTest();

        MyCarsAndPurchasesController.testContactIdOverride = null;

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.caseId);
        System.assertNotEquals(null, result.caseNumber);
        System.assertEquals('Service request for Service Vehicle: Brake noise when turning', result.subject);

        Case createdCase = [
            SELECT Id, ContactId, AccountId, Subject, Description, SuppliedPhone
            FROM Case
            WHERE Id = :result.caseId
            LIMIT 1
        ];
        System.assertEquals(buyer.Id, createdCase.ContactId);
        System.assertEquals(accountRecord.Id, createdCase.AccountId);
        System.assertEquals('Service request for Service Vehicle: Brake noise when turning', createdCase.Subject);
        System.assertEquals('Noise is louder after driving for 20 minutes.', createdCase.Description);
        System.assertEquals('415-555-0182', createdCase.SuppliedPhone);
    }
}