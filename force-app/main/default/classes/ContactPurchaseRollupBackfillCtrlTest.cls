@IsTest
private class ContactPurchaseRollupBackfillCtrlTest {
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

    @IsTest
    static void runBackfillUpdatesRollupFields() {
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

        Contact buyer = new Contact(LastName = 'Backfill Buyer');
        Contact noPurchaseContact = new Contact(LastName = 'No Purchase Contact');
        insert buyer;
        insert noPurchaseContact;

        insert new Purchase__c(
            Contact__c = buyer.Id,
            Purchased_Date__c = System.today(),
            Purchase_Price__c = 12345.67
        );
        insert new Purchase__c(
            Contact__c = buyer.Id,
            Purchased_Date__c = System.today(),
            Purchase_Price__c = 100.00
        );

        Test.startTest();
        ContactPurchaseRollupBackfillController.BackfillResult result =
            ContactPurchaseRollupBackfillController.runBackfill();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contactsWithPurchases >= 1, 'Expected at least one contact with purchases.');

        String soql = 'SELECT Id';
        if (totalAmountField != null) {
            soql += ', ' + totalAmountField;
        }
        if (purchaseCountField != null) {
            soql += ', ' + purchaseCountField;
        }
        soql += ' FROM Contact WHERE Id = :buyer.Id';
        Contact refreshed = Database.query(soql);

        if (purchaseCountField != null) {
            Integer actualCount = refreshed.get(purchaseCountField) == null
                ? 0
                : Integer.valueOf(String.valueOf(refreshed.get(purchaseCountField)));
            System.assertEquals(2, actualCount);
        }

        if (totalAmountField != null) {
            Decimal actualTotal = refreshed.get(totalAmountField) == null
                ? Decimal.valueOf(0)
                : Decimal.valueOf(String.valueOf(refreshed.get(totalAmountField))).setScale(2);
            System.assertEquals(Decimal.valueOf('12445.67'), actualTotal);
        }

        String noPurchaseSoql = 'SELECT Id';
        if (totalAmountField != null) {
            noPurchaseSoql += ', ' + totalAmountField;
        }
        if (purchaseCountField != null) {
            noPurchaseSoql += ', ' + purchaseCountField;
        }
        noPurchaseSoql += ' FROM Contact WHERE Id = :noPurchaseContact.Id';
        Contact refreshedNoPurchaseContact = Database.query(noPurchaseSoql);

        if (purchaseCountField != null) {
            Integer noPurchaseCount = refreshedNoPurchaseContact.get(purchaseCountField) == null
                ? 0
                : Integer.valueOf(String.valueOf(refreshedNoPurchaseContact.get(purchaseCountField)));
            System.assertEquals(0, noPurchaseCount);
        }
        if (totalAmountField != null) {
            Decimal noPurchaseTotal = refreshedNoPurchaseContact.get(totalAmountField) == null
                ? Decimal.valueOf(0)
                : Decimal.valueOf(String.valueOf(refreshedNoPurchaseContact.get(totalAmountField))).setScale(2);
            System.assertEquals(Decimal.valueOf(0), noPurchaseTotal);
        }
    }

    @IsTest
    static void runFromFlowReturnsOneResult() {
        Test.startTest();
        List<ContactPurchaseRollupBackfillController.BackfillResult> results =
            ContactPurchaseRollupBackfillController.runFromFlow(
                new List<ContactPurchaseRollupBackfillController.Request>{
                    new ContactPurchaseRollupBackfillController.Request()
                }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
    }
}
