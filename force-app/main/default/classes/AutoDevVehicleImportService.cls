public with sharing class AutoDevVehicleImportService {
    @TestVisible private static final String BASE_URL = 'https://api.auto.dev/listings';
    @TestVisible private static final Integer DEFAULT_LIMIT = 25;
    @TestVisible private static final Integer MAX_LIMIT = 500;
    @TestVisible private static final Integer HTTP_TIMEOUT_MS = 120000;

    @TestVisible private static String apiKeyOverride;
    @TestVisible private static String stateFilterOverride;
    @TestVisible private static List<String> cachedAllowedYears;
    @TestVisible private static List<String> cachedAllowedMakes;
    @TestVisible private static List<String> cachedAllowedColors;

    public class ImportResult {
        @AuraEnabled public Integer requested = 0;
        @AuraEnabled public Integer imported = 0;
        @AuraEnabled public Integer skippedExisting = 0;
        @AuraEnabled public Integer skippedMissingVin = 0;
        @AuraEnabled public Integer failed = 0;
        @AuraEnabled public List<String> failureMessages = new List<String>();
    }

    public class AutoDevServiceException extends Exception {}

    private class LocationAssignmentData {
        public Map<String, List<Id>> locationIdsByState = new Map<String, List<Id>>();
        public List<Id> allLocationIds = new List<Id>();
        public Map<String, Integer> stateOffsets = new Map<String, Integer>();
        public Integer allLocationOffset = 0;

        public Id nextLocationId(String stateCode) {
            if (!String.isBlank(stateCode) && locationIdsByState.containsKey(stateCode)) {
                List<Id> stateIds = locationIdsByState.get(stateCode);
                if (stateIds.size() > 1) {
                    Integer offset = stateOffsets.containsKey(stateCode) ? stateOffsets.get(stateCode) : 0;
                    Id selectedId = stateIds[Math.mod(offset, stateIds.size())];
                    stateOffsets.put(stateCode, offset + 1);
                    return selectedId;
                }
            }

            if (allLocationIds.isEmpty()) {
                return null;
            }

            Id fallbackId = allLocationIds[Math.mod(allLocationOffset, allLocationIds.size())];
            allLocationOffset++;
            return fallbackId;
        }
    }

    public static ImportResult importNightlyListings() {
        return importListings(DEFAULT_LIMIT);
    }

    public static ImportResult importListings(Integer requestedLimit) {
        Integer effectiveLimit = normalizeLimit(requestedLimit);
        HttpResponse response = sendRequest(MAX_LIMIT);

        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new AutoDevServiceException(
                'Auto.dev request failed with status ' + response.getStatusCode() + ': ' + response.getBody()
            );
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> rawListings = payload == null ? null : (List<Object>) payload.get('data');

        return importListingsFromPayload(rawListings, effectiveLimit);
    }

    @TestVisible
    private static ImportResult importListingsFromPayload(List<Object> rawListings, Integer requestedLimit) {
        ImportResult result = new ImportResult();
        result.requested = normalizeLimit(requestedLimit);

        if (rawListings == null || rawListings.isEmpty()) {
            return result;
        }

        List<Map<String, Object>> candidateListings = new List<Map<String, Object>>();
        Set<String> inboundVins = new Set<String>();
        Set<String> payloadVins = new Set<String>();

        for (Object rawListing : rawListings) {
            Map<String, Object> listing = (Map<String, Object>) rawListing;
            Map<String, Object> vehicle = getMap(listing, 'vehicle');
            String vin = firstNonBlank(safeString(listing.get('vin')), safeString(vehicle.get('vin')));

            if (String.isBlank(vin)) {
                result.skippedMissingVin++;
                continue;
            }

            if (!payloadVins.add(vin)) {
                result.skippedExisting++;
                continue;
            }

            inboundVins.add(vin);
            candidateListings.add(listing);
        }

        Set<String> existingVins = new Set<String>();
        if (!inboundVins.isEmpty()) {
            for (Automobile__c auto : [
                SELECT VIN__c
                FROM Automobile__c
                WHERE VIN__c IN :inboundVins
            ]) {
                if (!String.isBlank(auto.VIN__c)) {
                    existingVins.add(auto.VIN__c);
                }
            }
        }

        Map<String, Id> recordTypeIds = getRecordTypeIdsByName();
        Map<String, Id> dealershipIdsByMake = getDealershipIdsByMake(extractMakes(candidateListings));
        LocationAssignmentData locationData = getLocationAssignmentData();
        // Shuffle for make diversity before applying per-make limits
        for (Integer i = candidateListings.size() - 1; i > 0; i--) {
            Integer j = Math.mod(Math.abs(Crypto.getRandomInteger()), i + 1);
            Map<String, Object> temp = candidateListings[i];
            candidateListings[i] = candidateListings[j];
            candidateListings[j] = temp;
        }

        List<Automobile__c> autosToInsert = new List<Automobile__c>();
        Map<String, Integer> makeCount = new Map<String, Integer>();

        for (Map<String, Object> listing : candidateListings) {
            Map<String, Object> vehicle = getMap(listing, 'vehicle');
            String vin = firstNonBlank(safeString(listing.get('vin')), safeString(vehicle.get('vin')));

            if (existingVins.contains(vin)) {
                result.skippedExisting++;
                continue;
            }

            // Apply make cap early to avoid burning the pool on one make with many zero-price listings
            String rawMake = safeString(vehicle.get('make'));
            String resolvedMakeEarly = resolveMakeWithVinFallback(rawMake, vin);
            if (!String.isBlank(resolvedMakeEarly)) {
                Integer makesSeen = makeCount.containsKey(resolvedMakeEarly) ? makeCount.get(resolvedMakeEarly) : 0;
                if (makesSeen >= 2) {
                    continue;
                }
            }

            Automobile__c builtAuto = buildAutomobile(
                listing,
                vin,
                recordTypeIds,
                dealershipIdsByMake,
                locationData
            );

            if (String.isBlank(builtAuto.Bought_Via__c)) {
                result.failed++;
                result.failureMessages.add('Skipped VIN ' + vin + ': Bought_Via__c could not be resolved to Auto.dev');
                continue;
            }

            if (builtAuto.Value__c == null) {
                result.failed++;
                result.failureMessages.add('Skipped VIN ' + vin + ': no price returned from API');
                continue;
            }

            if (builtAuto.Value__c <= 0) {
                result.failed++;
                result.failureMessages.add('Skipped VIN ' + vin + ': price is zero or negative');
                continue;
            }

            if (String.isBlank(builtAuto.Make__c)) {
                result.failed++;
                result.failureMessages.add('Skipped VIN ' + vin + ': Make could not be resolved to a valid picklist value');
                continue;
            }

            Integer makesSeen = makeCount.containsKey(builtAuto.Make__c) ? makeCount.get(builtAuto.Make__c) : 0;
            if (makesSeen >= 2) {
                continue;
            }
            makeCount.put(builtAuto.Make__c, makesSeen + 1);
            autosToInsert.add(builtAuto);
            existingVins.add(vin);
            if (autosToInsert.size() >= result.requested) {
                break;
            }
        }

        if (autosToInsert.isEmpty()) {
            return result;
        }

        Database.SaveResult[] saveResults = Database.insert(autosToInsert, false);
        for (Database.SaveResult saveResult : saveResults) {
            if (saveResult.isSuccess()) {
                result.imported++;
            } else {
                result.failed++;
                for (Database.Error errorItem : saveResult.getErrors()) {
                    String message = errorItem.getStatusCode() + ': ' + errorItem.getMessage();
                    if (errorItem.getFields() != null && !errorItem.getFields().isEmpty()) {
                        message += ' [fields=' + String.join(errorItem.getFields(), ',') + ']';
                    }
                    result.failureMessages.add(message);
                }
            }
        }

        if (!result.failureMessages.isEmpty()) {
            for (Integer i = 0; i < Math.min(result.failureMessages.size(), 10); i++) {
                System.debug('AUTO_DEV_IMPORT_DML_ERROR ' + result.failureMessages[i]);
            }
            if (result.failureMessages.size() > 10) {
                System.debug('AUTO_DEV_IMPORT_DML_ERROR Additional errors omitted: ' + (result.failureMessages.size() - 10));
            }
        }

        return result;
    }

    @TestVisible
    private static HttpResponse sendRequest(Integer effectiveLimit) {
        HttpRequest request = buildRequest(effectiveLimit);
        Http http = new Http();
        return http.send(request);
    }

    @TestVisible
    private static HttpRequest buildRequest(Integer requestedLimit) {
        String apiKey = getApiKey();
        if (String.isBlank(apiKey) || apiKey == 'REPLACE_ME') {
            throw new AutoDevServiceException('Set the AutoDevApiKey custom label before running the nightly import.');
        }

        Integer effectiveLimit = normalizeLimit(requestedLimit);
        Integer page = Test.isRunningTest() ? 1 : (Math.mod(Math.abs(Crypto.getRandomInteger()), 10) + 1);
        String endpoint = BASE_URL + '?page=' + page + '&limit=' + effectiveLimit;
        String stateFilter = getStateFilter();
        if (!String.isBlank(stateFilter)) {
            endpoint += '&retailListing.state=' + EncodingUtil.urlEncode(stateFilter.trim().toUpperCase(), 'UTF-8');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(HTTP_TIMEOUT_MS);
        request.setHeader('Accept', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + apiKey);
        return request;
    }

    private static Automobile__c buildAutomobile(
        Map<String, Object> listing,
        String vin,
        Map<String, Id> recordTypeIds,
        Map<String, Id> dealershipIdsByMake,
        LocationAssignmentData locationData
    ) {
        Map<String, Object> vehicle = getMap(listing, 'vehicle');
        Map<String, Object> retailListing = getMap(listing, 'retailListing');
        Map<String, Object> wholesaleListing = getMap(listing, 'wholesaleListing');

        String make = safeString(vehicle.get('make'));
        String model = safeString(vehicle.get('model'));
        String color = firstNonBlank(
            safeString(vehicle.get('exteriorColor')),
            safeString(vehicle.get('interiorColor'))
        );
        String resolvedMake = resolveMakeWithVinFallback(make, vin);
        String resolvedColor = resolveRestrictedPicklistValue('Color__c', color);
        Integer year = safeInteger(vehicle.get('year'));
        Integer miles = firstNonNullInteger(
            safeInteger(retailListing.get('miles')),
            safeInteger(wholesaleListing.get('miles'))
        );
        Decimal marketPrice = firstNonNullDecimal(
            safeDecimal(retailListing.get('price')),
            safeDecimal(wholesaleListing.get('buyNowPrice'))
        );
        Boolean used = safeBoolean(retailListing.get('used'));
        String importSource = resolveRestrictedPicklistValue('Bought_Via__c', 'Auto.dev');
        String stateCode = firstNonBlank(
            safeString(retailListing.get('state')),
            safeString(wholesaleListing.get('state'))
        );

        Automobile__c auto = new Automobile__c(
            Name = buildVehicleName(make, model, vin)
        );
        auto.VIN__c = vin;
        auto.Bought__c = System.today();

        String yearValue = resolveYearValue(year);
        if (!String.isBlank(yearValue)) {
            auto.Year__c = yearValue;
        }
        if (miles != null) {
            auto.Mileage__c = miles;
        }
        if (!String.isBlank(resolvedMake)) {
            auto.Make__c = resolvedMake;
            if (dealershipIdsByMake.containsKey(resolvedMake)) {
                auto.Type_of_Dealership__c = dealershipIdsByMake.get(resolvedMake);
            }
        }
        if (!String.isBlank(resolvedColor)) {
            auto.Color__c = resolvedColor;
        }
        if (marketPrice != null) {
            Decimal scaledPrice = marketPrice.setScale(2);
            auto.Value__c = scaledPrice;
            auto.Original_Value__c = scaledPrice;
            auto.Sales_Price__c = scaledPrice;
            auto.Bought_Price__c = estimateBoughtPrice(scaledPrice, used);
        }

        Id recordTypeId = used ? recordTypeIds.get('Used') : recordTypeIds.get('New');
        if (recordTypeId != null) {
            auto.RecordTypeId = recordTypeId;
        }
        if (!String.isBlank(importSource)) {
            auto.Bought_Via__c = importSource;
        }

        Id locationId = locationData.nextLocationId(stateCode);
        if (locationId != null) {
            auto.Location__c = locationId;
        }

        return auto;
    }

    private static Map<String, Id> getRecordTypeIdsByName() {
        Map<String, Id> recordTypeIds = new Map<String, Id>();
        Map<String, Schema.RecordTypeInfo> byDeveloperName = Schema.SObjectType.Automobile__c.getRecordTypeInfosByDeveloperName();
        Map<String, Schema.RecordTypeInfo> byName = Schema.SObjectType.Automobile__c.getRecordTypeInfosByName();

        if (byDeveloperName.containsKey('New')) {
            recordTypeIds.put('New', byDeveloperName.get('New').getRecordTypeId());
        } else if (byName.containsKey('New')) {
            recordTypeIds.put('New', byName.get('New').getRecordTypeId());
        }

        if (byDeveloperName.containsKey('Used')) {
            recordTypeIds.put('Used', byDeveloperName.get('Used').getRecordTypeId());
        } else if (byName.containsKey('Used')) {
            recordTypeIds.put('Used', byName.get('Used').getRecordTypeId());
        }

        return recordTypeIds;
    }

    private static Map<String, Id> getDealershipIdsByMake(Set<String> makes) {
        Map<String, Id> dealershipIdsByMake = new Map<String, Id>();
        if (makes.isEmpty()) {
            return dealershipIdsByMake;
        }

        for (typeofdealership__c dealership : [
            SELECT Id, Name
            FROM typeofdealership__c
            WHERE Name IN :makes
        ]) {
            dealershipIdsByMake.put(dealership.Name, dealership.Id);
        }

        List<String> legacyNames = new List<String>();
        for (String make : makes) {
            legacyNames.add(make + ' Dealership');
        }

        for (typeofdealership__c dealership : [
            SELECT Id, Name
            FROM typeofdealership__c
            WHERE Name IN :legacyNames
        ]) {
            String normalizedMake = dealership.Name.replace(' Dealership', '');
            if (!dealershipIdsByMake.containsKey(normalizedMake)) {
                dealershipIdsByMake.put(normalizedMake, dealership.Id);
            }
        }

        List<typeofdealership__c> missingDealerships = new List<typeofdealership__c>();
        for (String make : makes) {
            if (!dealershipIdsByMake.containsKey(make)) {
                missingDealerships.add(new typeofdealership__c(Name = make));
            }
        }

        if (!missingDealerships.isEmpty()) {
            insert missingDealerships;
            for (typeofdealership__c dealership : missingDealerships) {
                dealershipIdsByMake.put(dealership.Name, dealership.Id);
            }
        }

        return dealershipIdsByMake;
    }

    private static LocationAssignmentData getLocationAssignmentData() {
        LocationAssignmentData locationData = new LocationAssignmentData();
        for (Schema.Location locationRecord : [
            SELECT Id, State__c
            FROM Location
            ORDER BY Name
            LIMIT 500
        ]) {
            locationData.allLocationIds.add(locationRecord.Id);
            if (String.isBlank(locationRecord.State__c)) {
                continue;
            }

            String stateCode = locationRecord.State__c.trim().toUpperCase();
            if (!locationData.locationIdsByState.containsKey(stateCode)) {
                locationData.locationIdsByState.put(stateCode, new List<Id>());
            }
            locationData.locationIdsByState.get(stateCode).add(locationRecord.Id);
        }
        return locationData;
    }

    private static Set<String> extractMakes(List<Map<String, Object>> listings) {
        Set<String> makes = new Set<String>();
        for (Map<String, Object> listing : listings) {
            String make = resolveRestrictedPicklistValue(
                'Make__c',
                safeString(getMap(listing, 'vehicle').get('make'))
            );
            if (!String.isBlank(make)) {
                makes.add(make);
            }
        }
        return makes;
    }

    private static Decimal estimateBoughtPrice(Decimal marketPrice, Boolean used) {
        if (marketPrice == null) {
            return null;
        }

        Decimal multiplier = used ? Decimal.valueOf('0.85') : Decimal.valueOf('0.70');
        return (marketPrice * multiplier).setScale(2);
    }

    private static Integer normalizeLimit(Integer requestedLimit) {
        if (requestedLimit == null || requestedLimit <= 0) {
            return DEFAULT_LIMIT;
        }
        return Math.min(requestedLimit, MAX_LIMIT);
    }

    private static String buildVehicleName(String make, String model, String vin) {
        String makePart = String.isBlank(make) ? 'Imported' : make.trim();
        String modelPart = String.isBlank(model) ? 'Vehicle' : model.trim();
        return makePart + ' ' + modelPart + ' - ' + vin;
    }

    private static Map<String, Object> getMap(Map<String, Object> source, String key) {
        Object value = source == null ? null : source.get(key);
        return value == null ? new Map<String, Object>() : (Map<String, Object>) value;
    }

    private static String getApiKey() {
        return Test.isRunningTest() && apiKeyOverride != null ? apiKeyOverride : System.Label.AutoDevApiKey;
    }

    private static String getStateFilter() {
        if (Test.isRunningTest() && stateFilterOverride != null) {
            return stateFilterOverride;
        }

        Set<String> statesWithLocations = new Set<String>();
        for (Schema.Location locationRecord : [
            SELECT State__c
            FROM Location
            WHERE State__c != null
            LIMIT 500
        ]) {
            String stateCode = locationRecord.State__c == null ? null : locationRecord.State__c.trim().toUpperCase();
            if (!String.isBlank(stateCode)) {
                statesWithLocations.add(stateCode);
            }
        }

        if (statesWithLocations.isEmpty()) {
            return null;
        }

        List<String> availableStates = new List<String>(statesWithLocations);
        Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), availableStates.size());
        return availableStates[idx];
    }

    private static String firstNonBlank(String firstValue, String secondValue) {
        return !String.isBlank(firstValue) ? firstValue : secondValue;
    }

    private static String resolveYearValue(Integer year) {
        if (year == null) {
            return null;
        }

        Integer normalizedYear = year;
        Integer currentYear = System.today().year();
        if (normalizedYear > currentYear) {
            normalizedYear = currentYear;
        }

        List<String> allowedYears = getAllowedYearValues();
        if (allowedYears.isEmpty()) {
            return null;
        }

        String requestedYear = String.valueOf(normalizedYear);
        if (allowedYears.contains(requestedYear)) {
            return requestedYear;
        }

        Integer fallbackYear = null;
        Integer maxYear = null;

        for (String allowedValue : allowedYears) {
            Integer parsedYear;
            try {
                parsedYear = Integer.valueOf(allowedValue);
            } catch (Exception ex) {
                continue;
            }

            if (maxYear == null || parsedYear > maxYear) {
                maxYear = parsedYear;
            }
            if (parsedYear <= normalizedYear && (fallbackYear == null || parsedYear > fallbackYear)) {
                fallbackYear = parsedYear;
            }
        }

        if (fallbackYear != null) {
            return String.valueOf(fallbackYear);
        }

        return maxYear == null ? null : String.valueOf(maxYear);
    }

    private static List<String> getAllowedYearValues() {
        if (cachedAllowedYears != null) {
            return cachedAllowedYears;
        }

        cachedAllowedYears = new List<String>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Automobile__c.fields.getMap();
        if (!fieldMap.containsKey('Year__c')) {
            return cachedAllowedYears;
        }

        for (Schema.PicklistEntry entry : fieldMap.get('Year__c').getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                cachedAllowedYears.add(entry.getValue());
            }
        }

        return cachedAllowedYears;
    }

    private static String resolveMakeWithVinFallback(String inboundMake, String vin) {
        String resolved = resolveRestrictedPicklistValue('Make__c', inboundMake);
        if (!String.isBlank(resolved)) {
            return resolved;
        }

        if (String.isBlank(vin) || vin.length() < 3) {
            return null;
        }

        String prefix3 = vin.substring(0, 3).toUpperCase();
        String inferredMake;
        if (prefix3 == '1G2') {
            inferredMake = 'Pontiac';
        } else if (prefix3 == 'SCB') {
            inferredMake = 'Bentley';
        } else if (prefix3 == '7FC') {
            inferredMake = 'Ineos';
        }

        return String.isBlank(inferredMake)
            ? null
            : resolveRestrictedPicklistValue('Make__c', inferredMake);
    }

    private static String resolveRestrictedPicklistValue(String fieldName, String inboundValue) {
        if (String.isBlank(inboundValue)) {
            return null;
        }

        List<String> allowedValues = getAllowedPicklistValues(fieldName);
        if (allowedValues.isEmpty()) {
            return inboundValue;
        }

        String trimmedValue = inboundValue.trim();
        if (allowedValues.contains(trimmedValue)) {
            return trimmedValue;
        }

        String normalizedInbound = normalizeText(trimmedValue);
        for (String allowedValue : allowedValues) {
            if (normalizeText(allowedValue) == normalizedInbound) {
                return allowedValue;
            }
        }

        // Prefer direct startsWith match so "Marina Blue Metallic" maps to "Blue".
        for (String allowedValue : allowedValues) {
            if (normalizedInbound.startsWith(normalizeText(allowedValue))) {
                return allowedValue;
            }
        }

        // Try first token fallback for values like "BMW" or "Mosaic Black Metallic".
        List<String> tokens = trimmedValue.split('\\s+');
        if (!tokens.isEmpty()) {
            String firstToken = tokens[0];
            for (String allowedValue : allowedValues) {
                if (normalizeText(allowedValue) == normalizeText(firstToken)) {
                    return allowedValue;
                }
            }
        }

        return null;
    }

    private static String normalizeText(String value) {
        return String.isBlank(value)
            ? ''
            : value.toLowerCase().replaceAll('[^a-z0-9]', '');
    }

    private static List<String> getAllowedPicklistValues(String fieldName) {
        if (fieldName == 'Make__c' && cachedAllowedMakes != null) {
            return cachedAllowedMakes;
        }
        if (fieldName == 'Color__c' && cachedAllowedColors != null) {
            return cachedAllowedColors;
        }

        List<String> allowedValues = new List<String>();
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Automobile__c.fields.getMap();
        if (!fieldMap.containsKey(fieldName)) {
            return allowedValues;
        }

        for (Schema.PicklistEntry entry : fieldMap.get(fieldName).getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                allowedValues.add(entry.getValue());
            }
        }

        if (fieldName == 'Make__c') {
            cachedAllowedMakes = allowedValues;
        } else if (fieldName == 'Color__c') {
            cachedAllowedColors = allowedValues;
        }

        return allowedValues;
    }

    private static Integer firstNonNullInteger(Integer firstValue, Integer secondValue) {
        return firstValue != null ? firstValue : secondValue;
    }

    private static Decimal firstNonNullDecimal(Decimal firstValue, Decimal secondValue) {
        return firstValue != null ? firstValue : secondValue;
    }

    private static String safeString(Object value) {
        return value == null ? null : String.valueOf(value).trim();
    }

    private static Integer safeInteger(Object value) {
        if (value == null) {
            return null;
        }

        if (value instanceof Integer) {
            return (Integer) value;
        }

        if (value instanceof Long) {
            return Integer.valueOf(String.valueOf(value));
        }

        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }

        String stringValue = String.valueOf(value);
        return String.isBlank(stringValue) ? null : Integer.valueOf(stringValue);
    }

    private static Decimal safeDecimal(Object value) {
        if (value == null) {
            return null;
        }

        if (value instanceof Decimal) {
            return (Decimal) value;
        }

        if (value instanceof Integer || value instanceof Long) {
            return Decimal.valueOf(String.valueOf(value));
        }

        String stringValue = String.valueOf(value);
        return String.isBlank(stringValue) ? null : Decimal.valueOf(stringValue);
    }

    private static Boolean safeBoolean(Object value) {
        if (value == null) {
            return false;
        }

        if (value instanceof Boolean) {
            return (Boolean) value;
        }

        return 'true'.equalsIgnoreCase(String.valueOf(value));
    }
}