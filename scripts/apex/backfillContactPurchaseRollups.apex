Map<String, Schema.SObjectField> contactFieldMap = Schema.SObjectType.Contact.fields.getMap();

String totalAmountField;
for (String candidate : new List<String>{
    'Total_Amount_Purchased__c',
    'TotalAmountPurchased__c',
    'Total_amount_purchased__c'
}) {
    if (contactFieldMap.containsKey(candidate)) {
        totalAmountField = candidate;
        break;
    }
}

String purchaseCountField;
for (String candidate : new List<String>{
    'Number_of_Purchases__c',
    'NumberOfPurchases__c',
    'Number_of_purchases__c'
}) {
    if (contactFieldMap.containsKey(candidate)) {
        purchaseCountField = candidate;
        break;
    }
}

if (totalAmountField == null || purchaseCountField == null) {
    String normalizedTotal = 'totalamountpurchased';
    String normalizedCount = 'numberofpurchases';

    for (String fieldName : contactFieldMap.keySet()) {
        String normalizedLabel = contactFieldMap
            .get(fieldName)
            .getDescribe()
            .getLabel()
            .replaceAll('[^A-Za-z0-9]', '')
            .toLowerCase();

        if (totalAmountField == null && normalizedLabel == normalizedTotal) {
            totalAmountField = fieldName;
        }
        if (purchaseCountField == null && normalizedLabel == normalizedCount) {
            purchaseCountField = fieldName;
        }

        if (totalAmountField != null && purchaseCountField != null) {
            break;
        }
    }
}

if (totalAmountField == null && purchaseCountField == null) {
    throw new AuraHandledException('No Contact rollup fields found for Total amount purchased / Number of Purchases.');
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

Set<Id> contactIds = new Set<Id>(aggregatesByContactId.keySet());

for (Contact c : [SELECT Id FROM Contact]) {
    contactIds.add(c.Id);
}

if (contactIds.isEmpty()) {
    System.debug('CONTACT_PURCHASE_ROLLUP_BACKFILL updated=0, contactsWithPurchases=' + aggregatesByContactId.size());
} else {
    List<Contact> contactUpdates = new List<Contact>();
    for (Id contactId : contactIds) {
        AggregateResult ar = aggregatesByContactId.get(contactId);
        Contact contactUpdate = new Contact(Id = contactId);

        if (totalAmountField != null) {
            Decimal totalAmount = ar == null || ar.get('totalAmount') == null
                ? Decimal.valueOf(0)
                : ((Decimal) ar.get('totalAmount')).setScale(2);
            contactUpdate.put(totalAmountField, totalAmount);
        }

        if (purchaseCountField != null) {
            Integer purchaseCount = ar == null || ar.get('purchaseCount') == null
                ? 0
                : Integer.valueOf(String.valueOf(ar.get('purchaseCount')));
            contactUpdate.put(purchaseCountField, purchaseCount);
        }

        contactUpdates.add(contactUpdate);
    }

    Integer successCount = 0;
    Integer failureCount = 0;
    if (!contactUpdates.isEmpty()) {
        Database.SaveResult[] results = Database.update(contactUpdates, false);
        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                for (Database.Error err : result.getErrors()) {
                    System.debug('Contact rollup backfill error: ' + err.getMessage());
                }
            }
        }
    }

    System.debug(
        'CONTACT_PURCHASE_ROLLUP_BACKFILL contactsWithPurchases=' + aggregatesByContactId.size() +
        ', updated=' + successCount +
        ', failed=' + failureCount +
        ', totalField=' + totalAmountField +
        ', countField=' + purchaseCountField
    );
}
