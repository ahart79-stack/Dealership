public with sharing class ContactPurchaseRollupBackfillController {
    public class Request {
        @InvocableVariable(label='Run Backfill')
        public Boolean runBackfill;
    }

    public class BackfillResult {
        @AuraEnabled @InvocableVariable public Integer contactsWithPurchases;
        @AuraEnabled @InvocableVariable public Integer updatedContacts;
        @AuraEnabled @InvocableVariable public Integer failedContacts;
        @AuraEnabled @InvocableVariable public String totalAmountField;
        @AuraEnabled @InvocableVariable public String purchaseCountField;
    }

    @AuraEnabled
    public static BackfillResult runBackfill() {
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
            throw new AuraHandledException(
                'No Contact rollup fields found for Total amount purchased / Number of Purchases.'
            );
        }

        Map<Id, AggregateResult> aggregatesByContactId = new Map<Id, AggregateResult>();
        for (AggregateResult ar : [
            SELECT Contact__c contactId, COUNT(Id) purchaseCount, SUM(Purchase_Price__c) totalAmount
            FROM Purchase__c
            WHERE Contact__c != null
            GROUP BY Contact__c
        ]) {
            aggregatesByContactId.put((Id) ar.get('contactId'), ar);
        }

        BackfillResult output = new BackfillResult();
        output.contactsWithPurchases = aggregatesByContactId.size();
        output.updatedContacts = 0;
        output.failedContacts = 0;
        output.totalAmountField = totalAmountField;
        output.purchaseCountField = purchaseCountField;

        List<Contact> allContacts = [SELECT Id FROM Contact];
        if (allContacts.isEmpty()) {
            return output;
        }

        List<Contact> contactUpdates = new List<Contact>();
        for (Contact contactRecord : allContacts) {
            AggregateResult ar = aggregatesByContactId.get(contactRecord.Id);
            Contact contactUpdate = new Contact(Id = contactRecord.Id);

            if (totalAmountField != null) {
                Decimal totalAmount = ar.get('totalAmount') == null
                    ? Decimal.valueOf(0)
                    : ((Decimal) ar.get('totalAmount')).setScale(2);
                contactUpdate.put(totalAmountField, totalAmount);
            }

            if (purchaseCountField != null) {
                Integer purchaseCount = ar.get('purchaseCount') == null
                    ? 0
                    : Integer.valueOf(String.valueOf(ar.get('purchaseCount')));
                contactUpdate.put(purchaseCountField, purchaseCount);
            }

            contactUpdates.add(contactUpdate);
        }

        Database.SaveResult[] results = Database.update(contactUpdates, false);
        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                output.updatedContacts++;
            } else {
                output.failedContacts++;
            }
        }

        return output;
    }

    @InvocableMethod(
        label='Backfill Contact Purchase Rollups'
        description='Recalculates total purchased amount and number of purchases on Contact from Purchase__c records.'
    )
    public static List<BackfillResult> runFromFlow(List<Request> requests) {
        return new List<BackfillResult>{ runBackfill() };
    }

    private static String firstExisting(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        for (String fieldName : candidates) {
            if (fieldMap.containsKey(fieldName)) {
                return fieldName;
            }
        }
        return null;
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

    private static String normalizeFieldLabel(String input) {
        if (String.isBlank(input)) {
            return '';
        }
        return input.replaceAll('[^A-Za-z0-9]', '').toLowerCase();
    }
}
