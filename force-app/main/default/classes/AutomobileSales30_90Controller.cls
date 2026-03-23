public with sharing class AutomobileSales30_90Controller {

    public class AutoDiscount {
        @AuraEnabled public Id    recordId       { get; set; }
        @AuraEnabled public String name          { get; set; }
        @AuraEnabled public String make          { get; set; }
        @AuraEnabled public String dealershipName { get; set; }
        @AuraEnabled public Date   boughtDate    { get; set; }
        @AuraEnabled public Integer daysOnField  { get; set; }
        @AuraEnabled public Decimal currentValue { get; set; }
        @AuraEnabled public Decimal discountedValue { get; set; }
        @AuraEnabled public String tier          { get; set; } // '30_60' or '60_plus'
    }

    /**
     * Returns automobiles still eligible for a first-time discount:
     *   tier '30_60'  — 30–60 days since Bought__c, X30_60_Discount__c not yet set → 15% off
     *   tier '60_plus' — >60 days since Bought__c, X60_90_Discount__c not yet set  → 25% off
     * Each discount is shown only once — records already discounted are excluded.
     */
    @AuraEnabled(cacheable=true)
    public static List<AutoDiscount> getDiscountEligibleAutos() {
        Date cutoff30 = Date.today().addDays(-30);
        Date today    = Date.today();

        Id soldRtId = getSoldRecordTypeId();

        String soql = 'SELECT Id, Name, Make__c, Bought__c, Value__c,' +
                  ' Type_of_Dealership__r.Name,' +
                      ' X30_60_Discount__c, X60_90_Discount__c' +
                      ' FROM Automobile__c' +
                      ' WHERE Bought__c != NULL AND Bought__c <= :cutoff30' +
                      ' AND (X30_60_Discount__c = NULL OR X60_90_Discount__c = NULL)';
        if (soldRtId != null) {
            soql += ' AND RecordTypeId != \'' + soldRtId + '\'';
        }
        soql += ' ORDER BY Bought__c ASC LIMIT 500';

        List<Automobile__c> autos = Database.query(soql);
        List<AutoDiscount> results = new List<AutoDiscount>();

        for (Automobile__c auto : autos) {
            Integer days = auto.Bought__c.daysBetween(today);
            if (days < 30) { continue; }

            // Skip if this tier's discount has already been applied
            if (days > 60  && auto.X60_90_Discount__c != null) { continue; }
            if (days <= 60 && auto.X30_60_Discount__c != null) { continue; }

            AutoDiscount ad  = new AutoDiscount();
            ad.recordId      = auto.Id;
            ad.name          = auto.Name;
            ad.make          = auto.Make__c;
            ad.dealershipName = auto.Type_of_Dealership__r != null ? auto.Type_of_Dealership__r.Name : null;
            ad.boughtDate    = auto.Bought__c;
            ad.daysOnField   = days;
            ad.currentValue  = auto.Value__c != null ? auto.Value__c : 0;

            if (days > 60) {
                ad.tier            = '60_plus';
                ad.discountedValue = (ad.currentValue * 0.25).setScale(2);
            } else {
                ad.tier            = '30_60';
                ad.discountedValue = (ad.currentValue * 0.15).setScale(2);
            }
            results.add(ad);
        }
        return results;
    }

    /**
     * Invocable entry point for Salesforce Flow / Process Builder.
     * Calls applyDiscounts() and surfaces the updated count as an output variable.
     */
    @InvocableMethod(
        label='Apply Automobile Value Discounts'
        description='Applies 15% (30-60 day) and 25% (60+ day) discounts to eligible unsold automobiles. Each discount is written only once per vehicle.'
        category='Automobile'
    )
    public static List<Integer> applyDiscountsInvocable(List<String> unused) {
        return new List<Integer>{ applyDiscounts() };
    }

    /**
     * Writes discount amounts to X30_60_Discount__c / X60_90_Discount__c.
     * Each field is written exactly once — already-populated discount fields are skipped.
     * Returns the number of records updated.
     */
    @AuraEnabled
    public static Integer applyDiscounts() {
        Date cutoff30 = Date.today().addDays(-30);
        Date today    = Date.today();

        Id soldRtId = getSoldRecordTypeId();

        String soql = 'SELECT Id, Bought__c, Value__c, Original_Value__c,' +
                      ' Sales_Price__c, X30_60_Discount__c, X60_90_Discount__c' +
                      ' FROM Automobile__c' +
                      ' WHERE Bought__c != NULL AND Bought__c <= :cutoff30' +
                      ' AND Value__c != NULL' +
                      ' AND (X30_60_Discount__c = NULL OR X60_90_Discount__c = NULL)';
        if (soldRtId != null) {
            soql += ' AND RecordTypeId != \'' + soldRtId + '\'';
        }
        soql += ' ORDER BY Bought__c ASC LIMIT 2000';

        List<Automobile__c> autos = Database.query(soql);
        List<Automobile__c> toUpdate = new List<Automobile__c>();

        for (Automobile__c auto : autos) {
            Integer days = auto.Bought__c.daysBetween(today);
            if (days < 30) { continue; }

            // Skip if this tier's discount has already been applied
            if (days > 60  && auto.X60_90_Discount__c != null) { continue; }
            if (days <= 60 && auto.X30_60_Discount__c != null) { continue; }

            Automobile__c upd = new Automobile__c(Id = auto.Id);
            // Capture original value if not already set
            if (auto.Original_Value__c == null) {
                upd.Original_Value__c = auto.Value__c;
            }
            Decimal discountAmt;
            if (days > 60) {
                discountAmt            = (auto.Value__c * 0.25).setScale(2);
                upd.X60_90_Discount__c = discountAmt;
            } else {
                discountAmt            = (auto.Value__c * 0.15).setScale(2);
                upd.X30_60_Discount__c = discountAmt;
            }
            upd.Sales_Price__c = (auto.Value__c - discountAmt).setScale(2);
            toUpdate.add(upd);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        return toUpdate.size();
    }

    // ─── private helpers ────────────────────────────────────────────────────────

    private static Id getSoldRecordTypeId() {
        Map<String, Schema.RecordTypeInfo> rtsByDev =
            Schema.SObjectType.Automobile__c.getRecordTypeInfosByDeveloperName();
        Map<String, Schema.RecordTypeInfo> rtsByName =
            Schema.SObjectType.Automobile__c.getRecordTypeInfosByName();
        if (rtsByDev.containsKey('Sold')) {
            return rtsByDev.get('Sold').getRecordTypeId();
        }
        if (rtsByName.containsKey('Sold')) {
            return rtsByName.get('Sold').getRecordTypeId();
        }
        return null;
    }
}
