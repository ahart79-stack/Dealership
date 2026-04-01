public with sharing class TopCustomersController {
    public class TopCustomerRow {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public Integer purchaseCount;
        @AuraEnabled public Decimal totalSpent;
        @AuraEnabled public Date lastPurchaseDate;

        public TopCustomerRow(
            Id contactId,
            String contactName,
            String email,
            String phone,
            Integer purchaseCount,
            Decimal totalSpent,
            Date lastPurchaseDate
        ) {
            this.contactId = contactId;
            this.contactName = contactName;
            this.email = email;
            this.phone = phone;
            this.purchaseCount = purchaseCount;
            this.totalSpent = totalSpent;
            this.lastPurchaseDate = lastPurchaseDate;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TopCustomerRow> getTopCustomers(Integer limitSize) {
        Integer effectiveLimit = limitSize == null || limitSize <= 0 ? 10 : Math.min(limitSize, 100);

        Map<Id, AggregateResult> aggregatesByContactId = new Map<Id, AggregateResult>();
        for (AggregateResult ar : [
            SELECT Contact__c contactId, COUNT(Id) purchaseCount, SUM(Purchase_Price__c) totalSpent, MAX(Purchased_Date__c) lastPurchaseDate
            FROM Purchase__c
            WHERE Contact__c != null
            GROUP BY Contact__c
            ORDER BY COUNT(Id) DESC, SUM(Purchase_Price__c) DESC, MAX(Purchased_Date__c) DESC
            LIMIT :effectiveLimit
        ]) {
            aggregatesByContactId.put((Id) ar.get('contactId'), ar);
        }

        if (aggregatesByContactId.isEmpty()) {
            return new List<TopCustomerRow>();
        }

        List<TopCustomerRow> rows = new List<TopCustomerRow>();
        for (Contact contactRecord : [
            SELECT Id, Name, Email, Phone
            FROM Contact
            WHERE Id IN :aggregatesByContactId.keySet()
            ORDER BY Name ASC
        ]) {
            AggregateResult aggregateRow = aggregatesByContactId.get(contactRecord.Id);
            rows.add(new TopCustomerRow(
                contactRecord.Id,
                contactRecord.Name,
                contactRecord.Email,
                contactRecord.Phone,
                Integer.valueOf(String.valueOf(aggregateRow.get('purchaseCount'))),
                (Decimal) aggregateRow.get('totalSpent'),
                (Date) aggregateRow.get('lastPurchaseDate')
            ));
        }

        rows.sort(new TopCustomerRowSorter());
        return rows;
    }

    private class TopCustomerRowSorter implements System.Comparator<TopCustomerRow> {
        public Integer compare(TopCustomerRow leftRow, TopCustomerRow rightRow) {
            if (leftRow.purchaseCount != rightRow.purchaseCount) {
                return rightRow.purchaseCount - leftRow.purchaseCount;
            }

            Decimal leftSpent = leftRow.totalSpent == null ? 0 : leftRow.totalSpent;
            Decimal rightSpent = rightRow.totalSpent == null ? 0 : rightRow.totalSpent;
            if (leftSpent != rightSpent) {
                return rightSpent > leftSpent ? 1 : -1;
            }

            String leftName = leftRow.contactName == null ? '' : leftRow.contactName;
            String rightName = rightRow.contactName == null ? '' : rightRow.contactName;
            return leftName.toLowerCase().compareTo(rightName.toLowerCase());
        }
    }
}