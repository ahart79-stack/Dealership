public with sharing class CurrentInventoryController {
    @AuraEnabled(cacheable=true)
    public static List<Automobile__c> getInventory(Integer limitSize) {
        if (limitSize == null || limitSize <= 0) {
            limitSize = 100;
        }
        return [
             SELECT Id, Name, Make__c, Year__c, Mileage__c, Value__c,
                 Number_of_Days_on_Lot__c,
                   Type_of_Dealership__c, Type_of_Dealership__r.Name,
                   RecordType.DeveloperName
            FROM Automobile__c
            ORDER BY CreatedDate DESC
            LIMIT :limitSize
        ];
    }
}
