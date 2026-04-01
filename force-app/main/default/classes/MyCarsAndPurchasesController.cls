public with sharing class MyCarsAndPurchasesController {
    @TestVisible
    private static Id testContactIdOverride;
    private static final String ALL_DAY_TIME_VALUE = 'ALL_DAY';

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class ServicePicklistData {
        @AuraEnabled public List<PicklistOption> typeOptions;
        @AuraEnabled public List<PicklistOption> subTypeOptions;

        public ServicePicklistData() {
            typeOptions = new List<PicklistOption>();
            subTypeOptions = new List<PicklistOption>();
        }
    }

    public class ServiceRequestResult {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;

        public ServiceRequestResult(Id caseId, String caseNumber, String subject) {
            this.caseId = caseId;
            this.caseNumber = caseNumber;
            this.subject = subject;
        }
    }

    public class DashboardData {
        @AuraEnabled public Boolean hasContact;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String contactPhone;
        @AuraEnabled public Integer automobileCount;
        @AuraEnabled public Integer purchaseCount;
        @AuraEnabled public Decimal totalSpent;
        @AuraEnabled public List<AutomobileRow> automobiles;
        @AuraEnabled public List<PurchaseRow> purchases;
        @AuraEnabled public Integer openCaseCount;
        @AuraEnabled public List<CaseRow> openCases;

        public DashboardData() {
            hasContact = false;
            automobileCount = 0;
            purchaseCount = 0;
            totalSpent = Decimal.valueOf(0);
            automobiles = new List<AutomobileRow>();
            purchases = new List<PurchaseRow>();
            openCaseCount = 0;
            openCases = new List<CaseRow>();
        }
    }

    public class AutomobileRow {
        @AuraEnabled public Id automobileId;
        @AuraEnabled public String name;
        @AuraEnabled public String make;
        @AuraEnabled public String year;
        @AuraEnabled public Decimal mileage;
        @AuraEnabled public Decimal salesPrice;

        public AutomobileRow(Automobile__c automobileRecord) {
            automobileId = automobileRecord.Id;
            name = automobileRecord.Name;
            make = automobileRecord.Make__c;
            year = automobileRecord.Year__c;
            mileage = automobileRecord.Mileage__c;
            salesPrice = automobileRecord.Sales_Price__c;
        }
    }

    public class PurchaseRow {
        @AuraEnabled public Id purchaseId;
        @AuraEnabled public String automobileName;
        @AuraEnabled public String make;
        @AuraEnabled public String year;
        @AuraEnabled public Decimal purchasePrice;
        @AuraEnabled public Date purchasedDate;

        public PurchaseRow(Purchase__c purchaseRecord) {
            purchaseId = purchaseRecord.Id;
            automobileName = purchaseRecord.Automobile__r == null
                ? null
                : purchaseRecord.Automobile__r.Name;
            make = purchaseRecord.Automobile__r == null
                ? null
                : purchaseRecord.Automobile__r.Make__c;
            year = purchaseRecord.Automobile__r == null
                ? null
                : purchaseRecord.Automobile__r.Year__c;
            purchasePrice = purchaseRecord.Purchase_Price__c;
            purchasedDate = purchaseRecord.Purchased_Date__c;
        }
    }

    public class CaseRow {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public Date openedDate;

        public CaseRow(Case caseRecord) {
            caseId = caseRecord.Id;
            caseNumber = caseRecord.CaseNumber;
            subject = caseRecord.Subject;
            status = caseRecord.Status;
            openedDate = caseRecord.CreatedDate == null ? null : caseRecord.CreatedDate.date();
        }
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData getMyCarsAndPurchases() {
        DashboardData output = new DashboardData();
        Id contactId = resolveCurrentContactId();
        if (contactId == null) {
            return output;
        }

        Contact contactRecord = [
            SELECT Id, Name, Phone, MobilePhone
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        output.hasContact = true;
        output.contactId = contactRecord.Id;
        output.contactName = contactRecord.Name;
        output.contactPhone = String.isBlank(contactRecord.Phone)
            ? contactRecord.MobilePhone
            : contactRecord.Phone;

        for (Automobile__c automobileRecord : [
            SELECT Id, Name, Make__c, Year__c, Mileage__c, Sales_Price__c
            FROM Automobile__c
            WHERE Buyer__c = :contactId
            ORDER BY Sold__c DESC, CreatedDate DESC
            LIMIT 200
        ]) {
            output.automobiles.add(new AutomobileRow(automobileRecord));
        }

        for (Purchase__c purchaseRecord : [
            SELECT Id, Purchase_Price__c, Purchased_Date__c,
                   Automobile__r.Name, Automobile__r.Make__c, Automobile__r.Year__c
            FROM Purchase__c
            WHERE Contact__c = :contactId
            ORDER BY Purchased_Date__c DESC, CreatedDate DESC
            LIMIT 200
        ]) {
            output.purchases.add(new PurchaseRow(purchaseRecord));
            if (purchaseRecord.Purchase_Price__c != null) {
                output.totalSpent += purchaseRecord.Purchase_Price__c;
            }
        }

        output.automobileCount = output.automobiles.size();
        output.purchaseCount = output.purchases.size();

        for (Case caseRecord : [
            SELECT Id, CaseNumber, Subject, Status, CreatedDate
            FROM Case
            WHERE ContactId = :contactId AND IsClosed = false
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            output.openCases.add(new CaseRow(caseRecord));
        }
        output.openCaseCount = output.openCases.size();

        return output;
    }

    @AuraEnabled(cacheable=true)
    public static ServicePicklistData getServicePicklistData() {
        ServicePicklistData result = new ServicePicklistData();
        result.typeOptions = getActivePicklistOptions('Case', 'Type');
        if (result.typeOptions.isEmpty()) {
            result.typeOptions = getActivePicklistOptions('Case', 'Type__c');
        }
        result.subTypeOptions = getActivePicklistOptions('Case', 'Sub_Type__c');
        if (result.subTypeOptions.isEmpty()) {
            result.subTypeOptions = getActivePicklistOptions('Case', 'SubType__c');
        }
        return result;
    }

    @AuraEnabled
    public static ServiceRequestResult submitServiceRequest(Id automobileId) {
        return submitDetailedServiceRequest(automobileId, 'General service request', null, null, null, null, null, null, null);
    }

    @AuraEnabled
    public static ServiceRequestResult submitDetailedServiceRequest(
        Id automobileId,
        String concernSummary,
        String serviceType,
        String serviceSubType,
        Decimal serviceMileage,
        String preferredServiceDate,
        String serviceTime,
        String contactPhone,
        String additionalDetails
    ) {
        if (automobileId == null) {
            throw new AuraHandledException('Select a car before submitting a service request.');
        }

        Id contactId = resolveCurrentContactId();
        if (contactId == null) {
            throw new AuraHandledException('This user does not have a linked contact.');
        }

        Contact contactRecord = [
            SELECT Id, Name, AccountId
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        List<Automobile__c> automobiles = [
            SELECT Id, Name, Buyer__c
            FROM Automobile__c
            WHERE Id = :automobileId AND Buyer__c = :contactId
            LIMIT 1
        ];
        if (automobiles.isEmpty()) {
            throw new AuraHandledException('The selected car is not available for this user.');
        }

        Automobile__c automobileRecord = automobiles[0];
        String trimmedConcernSummary = concernSummary == null
            ? null
            : concernSummary.trim();
        if (String.isBlank(trimmedConcernSummary)) {
            trimmedConcernSummary = 'General service request';
        }
        if (serviceMileage == null) {
            throw new AuraHandledException('Milage is required to submit a service request.');
        }

        String subject = 'Service request for ' + automobileRecord.Name + ': ' + trimmedConcernSummary;
        if (subject.length() > 255) {
            subject = subject.substring(0, 255);
        }

        Date preferredDate;
        if (String.isBlank(preferredServiceDate)) {
            throw new AuraHandledException('Preferred service date is required.');
        }
        try {
            preferredDate = Date.valueOf(preferredServiceDate);
        } catch (Exception ex) {
            throw new AuraHandledException('Preferred service date is invalid.');
        }
        if (isSunday(preferredDate)) {
            throw new AuraHandledException('Sundays are not available for preferred service dates.');
        }

        Time preferredTime;
        if (String.isBlank(serviceTime)) {
            throw new AuraHandledException('Preferred service time is required.');
        }
        if (serviceTime != ALL_DAY_TIME_VALUE) {
            try {
                preferredTime = parseServiceTime(serviceTime);
            } catch (Exception ex) {
                throw new AuraHandledException('Preferred service time is invalid.');
            }
        }

        Case serviceCase = new Case();
        Map<String, Schema.SObjectField> caseFieldMap = Schema.SObjectType.Case.fields.getMap();
        serviceCase.ContactId = contactRecord.Id;
        if (contactRecord.AccountId != null) {
            serviceCase.AccountId = contactRecord.AccountId;
        }
        serviceCase.Subject = subject;
        if (!String.isBlank(serviceType)) {
            assignCaseTextValue(
                serviceCase,
                caseFieldMap,
                new List<String>{ 'Type', 'Type__c' },
                serviceType.trim()
            );
        }
        if (!String.isBlank(serviceSubType)) {
            assignCaseTextValue(
                serviceCase,
                caseFieldMap,
                new List<String>{ 'Sub_Type__c', 'SubType__c' },
                serviceSubType.trim()
            );
        }
        assignCaseMileageValue(serviceCase, caseFieldMap, serviceMileage);
        assignCasePreferredDateValue(serviceCase, caseFieldMap, preferredDate);
        assignCaseTimeValue(serviceCase, caseFieldMap, serviceTime, preferredTime);
        if (!String.isBlank(contactPhone)) {
            serviceCase.SuppliedPhone = contactPhone.trim();
        }

        serviceCase.Description = String.isBlank(additionalDetails)
            ? null
            : additionalDetails.trim();

        String originValue = resolveCasePicklistValue('Origin', 'Web');
        if (originValue != null) {
            serviceCase.Origin = originValue;
        }

        insert serviceCase;

        Case insertedCase = [
            SELECT Id, CaseNumber, Subject
            FROM Case
            WHERE Id = :serviceCase.Id
            LIMIT 1
        ];

        return new ServiceRequestResult(insertedCase.Id, insertedCase.CaseNumber, insertedCase.Subject);
    }

    private static String resolveCasePicklistValue(String fieldName, String preferredValue) {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
        if (!fieldMap.containsKey(fieldName)) {
            return null;
        }

        String firstActiveValue;
        for (Schema.PicklistEntry entry : fieldMap.get(fieldName).getDescribe().getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }

            String value = entry.getValue();
            if (firstActiveValue == null) {
                firstActiveValue = value;
            }
            if (value == preferredValue) {
                return value;
            }
        }

        return firstActiveValue;
    }

    private static Boolean isSunday(Date dateValue) {
        DateTime noon = DateTime.newInstance(dateValue, Time.newInstance(12, 0, 0, 0));
        return Integer.valueOf(noon.format('u')) == 7;
    }

    private static Time parseServiceTime(String serviceTime) {
        List<String> parts = serviceTime.split(':');
        if (parts.size() != 2) {
            throw new AuraHandledException('Preferred service time is invalid.');
        }

        Integer hourValue = Integer.valueOf(parts[0]);
        Integer minuteValue = Integer.valueOf(parts[1]);
        if (hourValue < 0 || hourValue > 23 || minuteValue < 0 || minuteValue > 59) {
            throw new AuraHandledException('Preferred service time is invalid.');
        }

        return Time.newInstance(hourValue, minuteValue, 0, 0);
    }

    private static List<PicklistOption> getActivePicklistOptions(String objectApiName, String fieldApiName) {
        List<PicklistOption> output = new List<PicklistOption>();

        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        if (objectType == null) {
            return output;
        }

        Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return output;
        }

        for (Schema.PicklistEntry entry : fieldMap.get(fieldApiName).getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                output.add(new PicklistOption(entry.getLabel(), entry.getValue()));
            }
        }

        return output;
    }

    private static void assignCaseTextValue(
        Case targetCase,
        Map<String, Schema.SObjectField> caseFieldMap,
        List<String> fieldCandidates,
        String value
    ) {
        for (String fieldName : fieldCandidates) {
            if (!caseFieldMap.containsKey(fieldName)) {
                continue;
            }

            Schema.DisplayType fieldType = caseFieldMap.get(fieldName).getDescribe().getType();
            if (fieldType == Schema.DisplayType.String ||
                fieldType == Schema.DisplayType.TextArea ||
                fieldType == Schema.DisplayType.Picklist) {
                targetCase.put(fieldName, value);
                return;
            }
        }
    }

    private static void assignCaseMileageValue(
        Case targetCase,
        Map<String, Schema.SObjectField> caseFieldMap,
        Decimal mileageValue
    ) {
        for (String fieldName : new List<String>{ 'Milage__c', 'Mileage__c' }) {
            if (!caseFieldMap.containsKey(fieldName)) {
                continue;
            }

            Schema.DisplayType fieldType = caseFieldMap.get(fieldName).getDescribe().getType();
            if (fieldType == Schema.DisplayType.Double ||
                fieldType == Schema.DisplayType.Integer ||
                fieldType == Schema.DisplayType.Currency ||
                fieldType == Schema.DisplayType.Percent) {
                targetCase.put(fieldName, mileageValue);
                return;
            }
            if (fieldType == Schema.DisplayType.String || fieldType == Schema.DisplayType.TextArea) {
                targetCase.put(fieldName, String.valueOf(mileageValue));
                return;
            }
        }
    }

    private static void assignCasePreferredDateValue(
        Case targetCase,
        Map<String, Schema.SObjectField> caseFieldMap,
        Date preferredDate
    ) {
        for (String fieldName : new List<String>{ 'Preferred_Date__c', 'Preferred_Service_Date__c' }) {
            if (!caseFieldMap.containsKey(fieldName)) {
                continue;
            }

            Schema.DisplayType fieldType = caseFieldMap.get(fieldName).getDescribe().getType();
            if (fieldType == Schema.DisplayType.Date) {
                targetCase.put(fieldName, preferredDate);
                return;
            }
            if (fieldType == Schema.DisplayType.String || fieldType == Schema.DisplayType.TextArea) {
                targetCase.put(fieldName, String.valueOf(preferredDate));
                return;
            }
        }
    }

    private static void assignCaseTimeValue(
        Case targetCase,
        Map<String, Schema.SObjectField> caseFieldMap,
        String serviceTime,
        Time preferredTime
    ) {
        for (String fieldName : new List<String>{ 'Time__c', 'Preferred_Time__c' }) {
            if (!caseFieldMap.containsKey(fieldName)) {
                continue;
            }

            Schema.DisplayType fieldType = caseFieldMap.get(fieldName).getDescribe().getType();
            if (serviceTime == ALL_DAY_TIME_VALUE) {
                if (fieldType == Schema.DisplayType.String ||
                    fieldType == Schema.DisplayType.TextArea ||
                    fieldType == Schema.DisplayType.Picklist) {
                    targetCase.put(fieldName, serviceTime);
                    return;
                }
                continue;
            }

            if (preferredTime != null && fieldType == Schema.DisplayType.Time) {
                targetCase.put(fieldName, preferredTime);
                return;
            }
            if (fieldType == Schema.DisplayType.String ||
                fieldType == Schema.DisplayType.TextArea ||
                fieldType == Schema.DisplayType.Picklist) {
                targetCase.put(fieldName, serviceTime);
                return;
            }
        }
    }

    private static Id resolveCurrentContactId() {
        if (Test.isRunningTest() && testContactIdOverride != null) {
            return testContactIdOverride;
        }

        User currentUser = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return currentUser.ContactId;
    }
}