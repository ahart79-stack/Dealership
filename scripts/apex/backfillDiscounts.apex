// Backfill X30_60_Discount__c and X60_90_Discount__c for existing Automobile__c records
Integer updated = AutomobileSales30_90Controller.applyDiscounts();
System.debug('Backfill complete. Discounts applied to ' + updated + ' records.');
