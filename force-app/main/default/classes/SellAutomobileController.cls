public with sharing class SellAutomobileController {
    @TestVisible private static Integer nightlyMinOverride;
    @TestVisible private static Integer nightlyMaxOverride;

    @AuraEnabled
    public static Integer sellRandomAutos(Integer count) {
        try {
            if (count == null || count <= 0) {
                count = 10;
            }

            return sellAutos(count, false);
        } catch (Exception e) {
            throw e;
        }
    }

    public static Integer sellNightlyAutos() {
        try {
            Integer minCount = nightlyMinOverride == null ? 15 : nightlyMinOverride;
            Integer maxCount = nightlyMaxOverride == null ? 20 : nightlyMaxOverride;
            Integer count = randomBetween(minCount, maxCount);
            return sellAutos(count, true);
        } catch (Exception e) {
            throw e;
        }
    }

    private static Integer sellAutos(Integer count, Boolean spreadAcrossLocations) {
        try {
            if (count == null || count <= 0) {
                return 0;
            }

            // Load a pool of contacts to attach to sold vehicles
            List<Contact> contactPool = [SELECT Id FROM Contact LIMIT 200];

            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Automobile__c.fields.getMap();
            if (!fieldMap.containsKey('Bought__c')) {
                throw new AuraHandledException('Automobile__c.Bought__c is required to sell vehicles with date logic.');
            }

            String soldDateField = firstExisting(fieldMap, new List<String>{
                'Sold_Date__c', 'Date_Sold__c', 'SoldOn__c', 'Sold_DateTime__c'
            });
            String soldPriceField = firstExisting(fieldMap, new List<String>{
                'Sold_Price__c', 'Sale_Price__c'
            });
            String profitField = firstExisting(fieldMap, new List<String>{
                'Profit__c', 'Profit_Amount__c'
            });
            String boughtPriceField = firstExisting(fieldMap, new List<String>{
                'Bought_Price__c', 'Purchase_Price__c', 'Cost__c'
            });
            String soldFlagField = firstExisting(fieldMap, new List<String>{'Sold__c'});
            String statusField = firstExisting(fieldMap, new List<String>{'Status__c'});
            Id soldRecordTypeId;
            Map<String, Schema.RecordTypeInfo> recordTypesByDevName = Schema.SObjectType.Automobile__c.getRecordTypeInfosByDeveloperName();
            Map<String, Schema.RecordTypeInfo> recordTypesByName = Schema.SObjectType.Automobile__c.getRecordTypeInfosByName();
            if (recordTypesByDevName.containsKey('Sold')) {
                soldRecordTypeId = recordTypesByDevName.get('Sold').getRecordTypeId();
            } else if (recordTypesByName.containsKey('Sold')) {
                soldRecordTypeId = recordTypesByName.get('Sold').getRecordTypeId();
            }
            String locationField = firstExisting(fieldMap, new List<String>{'Location__c'});
            Schema.DisplayType soldDateType = soldDateField == null
                ? null
                : fieldMap.get(soldDateField).getDescribe().getType();
            Schema.DisplayType soldFlagType = soldFlagField == null
                ? null
                : fieldMap.get(soldFlagField).getDescribe().getType();

            Integer querySize = Math.max(count * 8, 100);
            String selectFields = 'Id, Bought__c, Value__c';
            if (fieldMap.containsKey('Make__c')) {
                selectFields += ', Make__c';
            }
            if (fieldMap.containsKey('Year__c')) {
                selectFields += ', Year__c';
            }
            if (boughtPriceField != null) {
                selectFields += ', ' + boughtPriceField;
            }
            if (locationField != null) {
                selectFields += ', ' + locationField;
            }

            String soql = 'SELECT ' + selectFields +
                ' FROM Automobile__c' +
                ' WHERE Bought__c != NULL';
            if (soldRecordTypeId != null) {
                soql += ' AND RecordTypeId != \'' + soldRecordTypeId + '\'';
            }
            if (statusField != null) {
                soql += ' AND (' + statusField + ' = NULL OR ' + statusField + ' != \'Sold\')';
            }
            if (spreadAcrossLocations && locationField != null) {
                soql += ' AND ' + locationField + ' != NULL';
            }
            soql += ' ORDER BY CreatedDate DESC' +
                ' LIMIT ' + querySize;
            List<Automobile__c> candidates = Database.query(soql);

            if (candidates.isEmpty()) {
                return 0;
            }

            List<Automobile__c> selectedCandidates = spreadAcrossLocations && locationField != null
                ? selectCandidatesAcrossLocations(candidates, count, locationField)
                : selectCandidatesRandomly(candidates, count);

            if (selectedCandidates.isEmpty()) {
                return 0;
            }

            List<Automobile__c> updates = new List<Automobile__c>();
            List<Id> selectedBuyerIds = new List<Id>();
            List<Automobile__c> selectedSources = new List<Automobile__c>();
            List<Date> selectedSoldDates = new List<Date>();
            List<Decimal> selectedSalePrices = new List<Decimal>();

            for (Automobile__c source : selectedCandidates) {
                Date boughtDate = (Date) source.get('Bought__c');
                Date soldDate = randomSoldDate(boughtDate);

                Decimal baselinePrice = source.Value__c == null ? Decimal.valueOf(15000) : source.Value__c;
                Decimal costBasis;

                if (boughtPriceField != null && source.get(boughtPriceField) != null) {
                    Object rawCost = source.get(boughtPriceField);
                    costBasis = rawCost instanceof Decimal
                        ? (Decimal) rawCost
                        : Decimal.valueOf(String.valueOf(rawCost));
                } else {
                    Decimal marginPct = Decimal.valueOf(8 + Math.mod(Math.abs(Crypto.getRandomInteger()), 18));
                    costBasis = (baselinePrice * (Decimal.valueOf(100) - marginPct)) / Decimal.valueOf(100);
                }

                // About 25% of sales are losses to better mimic real inventory outcomes.
                Boolean isLossSale = Math.mod(Math.abs(Crypto.getRandomInteger()), 100) < 25;
                Decimal pctDelta = isLossSale
                    ? Decimal.valueOf(3 + Math.mod(Math.abs(Crypto.getRandomInteger()), 16))
                    : Decimal.valueOf(5 + Math.mod(Math.abs(Crypto.getRandomInteger()), 18));
                Decimal salePrice = isLossSale
                    ? (costBasis * (Decimal.valueOf(100) - pctDelta)) / Decimal.valueOf(100)
                    : (costBasis * (Decimal.valueOf(100) + pctDelta)) / Decimal.valueOf(100);
                salePrice = salePrice.setScale(2);
                Decimal profit = (salePrice - costBasis).setScale(2);
                Automobile__c row = new Automobile__c(Id = source.Id);

                if (soldDateField != null) {
                    if (soldDateType == Schema.DisplayType.DateTime) {
                        row.put(soldDateField, DateTime.newInstance(soldDate, Time.newInstance(12, 0, 0, 0)));
                    } else {
                        row.put(soldDateField, soldDate);
                    }
                }
                if (soldPriceField != null) {
                    row.put(soldPriceField, salePrice);
                }
                if (profitField != null) {
                    row.put(profitField, profit);
                }
                if (soldFlagField != null) {
                    if (soldFlagType == Schema.DisplayType.Boolean) {
                        row.put(soldFlagField, true);
                    } else if (soldFlagType == Schema.DisplayType.Date) {
                        row.put(soldFlagField, soldDate);
                    } else if (soldFlagType == Schema.DisplayType.DateTime) {
                        row.put(soldFlagField, DateTime.newInstance(soldDate, Time.newInstance(12, 0, 0, 0)));
                    } else if (soldFlagType == Schema.DisplayType.Picklist || soldFlagType == Schema.DisplayType.String) {
                        row.put(soldFlagField, 'Sold');
                    }
                }
                if (statusField != null) {
                    row.put(statusField, 'Sold');
                }
                // Attach a random contact as the buyer
                Id buyerId;
                if (!contactPool.isEmpty() && fieldMap.containsKey('Buyer__c')) {
                    Integer contactIdx = Math.mod(Math.abs(Crypto.getRandomInteger()), contactPool.size());
                    buyerId = contactPool[contactIdx].Id;
                    row.Buyer__c = buyerId;
                }
                // RecordType is changed in a separate DML pass below

                updates.add(row);
                selectedBuyerIds.add(buyerId);
                selectedSources.add(source);
                selectedSoldDates.add(soldDate);
                selectedSalePrices.add(salePrice);
            }

            if (updates.isEmpty()) {
                return 0;
            }

            Integer soldCount = 0;
            List<String> errors = new List<String>();
            Database.SaveResult[] results = Database.update(updates, false);
            List<Automobile__c> rtUpdates = new List<Automobile__c>();
            List<Purchase__c> purchaseInserts = new List<Purchase__c>();
            Set<Id> contactIdsToRollup = new Set<Id>();
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    soldCount++;
                    if (soldRecordTypeId != null) {
                        rtUpdates.add(new Automobile__c(Id = updates[i].Id, RecordTypeId = soldRecordTypeId));
                    }
                    if (selectedBuyerIds[i] != null) {
                        contactIdsToRollup.add(selectedBuyerIds[i]);
                        purchaseInserts.add(new Purchase__c(
                            Automobile__c = updates[i].Id,
                            Contact__c = selectedBuyerIds[i],
                            Make__c = selectedSources[i].Make__c,
                            Year__c = selectedSources[i].Year__c == null ? null : String.valueOf(selectedSources[i].Year__c),
                            Purchased_Date__c = selectedSoldDates[i],
                            Purchase_Price__c = selectedSalePrices[i] == null ? null : selectedSalePrices[i].setScale(2)
                        ));
                    }
                } else {
                    for (Database.Error e : results[i].getErrors()) {
                        errors.add(e.getMessage());
                    }
                }
            }
            // Best-effort record type change — don't let failures here roll back the sell
            if (!rtUpdates.isEmpty()) {
                Database.update(rtUpdates, false);
            }
            if (!purchaseInserts.isEmpty()) {
                Database.SaveResult[] purchaseResults = Database.insert(purchaseInserts, false);
                for (Database.SaveResult purchaseResult : purchaseResults) {
                    if (!purchaseResult.isSuccess()) {
                        for (Database.Error e : purchaseResult.getErrors()) {
                            errors.add('Purchase creation failed: ' + e.getMessage());
                        }
                    }
                }
            }
            if (!contactIdsToRollup.isEmpty()) {
                rollupContactPurchaseMetrics(contactIdsToRollup);
            }
            if (soldCount == 0 && !errors.isEmpty()) {
                throw new AuraHandledException('No cars sold. Errors: ' + String.join(errors, '; '));
            }
            return soldCount;
        } catch (Exception e) {
            throw e;
        }
    }

    @TestVisible
    private static List<Automobile__c> selectCandidatesRandomly(List<Automobile__c> candidates, Integer count) {
        List<Automobile__c> pool = new List<Automobile__c>(candidates);
        shuffleAutomobiles(pool);

        Integer target = Math.min(count, pool.size());
        List<Automobile__c> selected = new List<Automobile__c>();
        for (Integer i = 0; i < target; i++) {
            selected.add(pool[i]);
        }
        return selected;
    }

    @TestVisible
    private static List<Automobile__c> selectCandidatesAcrossLocations(
        List<Automobile__c> candidates,
        Integer count,
        String locationField
    ) {
        Map<Id, List<Automobile__c>> locationToAutos = new Map<Id, List<Automobile__c>>();
        List<Id> locationIds = new List<Id>();

        for (Automobile__c candidate : candidates) {
            Id locationId = (Id) candidate.get(locationField);
            if (locationId == null) {
                continue;
            }
            if (!locationToAutos.containsKey(locationId)) {
                locationToAutos.put(locationId, new List<Automobile__c>());
                locationIds.add(locationId);
            }
            locationToAutos.get(locationId).add(candidate);
        }

        if (locationIds.isEmpty()) {
            return new List<Automobile__c>();
        }

        shuffleIds(locationIds);
        for (Id locationId : locationIds) {
            shuffleAutomobiles(locationToAutos.get(locationId));
        }

        Integer target = Math.min(count, candidates.size());
        List<Automobile__c> selected = new List<Automobile__c>();
        Integer locationIndex = 0;
        while (selected.size() < target && !locationIds.isEmpty()) {
            if (locationIndex >= locationIds.size()) {
                locationIndex = 0;
            }

            Id locationId = locationIds[locationIndex];
            List<Automobile__c> pool = locationToAutos.get(locationId);
            if (pool.isEmpty()) {
                locationIds.remove(locationIndex);
                continue;
            }

            selected.add(pool.remove(0));
            if (pool.isEmpty()) {
                locationIds.remove(locationIndex);
            } else {
                locationIndex++;
            }
        }

        return selected;
    }

    @TestVisible
    private static Integer randomBetween(Integer minValue, Integer maxValue) {
        Integer safeMin = minValue == null ? 15 : minValue;
        Integer safeMax = maxValue == null ? 20 : maxValue;
        if (safeMin > safeMax) {
            Integer swap = safeMin;
            safeMin = safeMax;
            safeMax = swap;
        }

        Integer span = safeMax - safeMin;
        Integer offset = span == 0 ? 0 : Math.mod(Math.abs(Crypto.getRandomInteger()), span + 1);
        return safeMin + offset;
    }

    @TestVisible
    private static void shuffleAutomobiles(List<Automobile__c> items) {
        if (items == null || items.size() <= 1) {
            return;
        }

        for (Integer i = items.size() - 1; i > 0; i--) {
            Integer j = Math.mod(Math.abs(Crypto.getRandomInteger()), i + 1);
            Automobile__c current = items[i];
            items[i] = items[j];
            items[j] = current;
        }
    }

    @TestVisible
    private static void shuffleIds(List<Id> items) {
        if (items == null || items.size() <= 1) {
            return;
        }

        for (Integer i = items.size() - 1; i > 0; i--) {
            Integer j = Math.mod(Math.abs(Crypto.getRandomInteger()), i + 1);
            Id current = items[i];
            items[i] = items[j];
            items[j] = current;
        }
    }

    private static Date randomSoldDate(Date boughtDate) {
        return System.today();
    }

    @TestVisible
    private static void rollupContactPurchaseMetrics(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return;
        }

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

        Map<Id, AggregateResult> aggregatesByContactId = new Map<Id, AggregateResult>();
        for (AggregateResult ar : [
            SELECT Contact__c contactId, COUNT(Id) purchaseCount, SUM(Purchase_Price__c) totalAmount
            FROM Purchase__c
            WHERE Contact__c IN :contactIds
            GROUP BY Contact__c
        ]) {
            aggregatesByContactId.put((Id) ar.get('contactId'), ar);
        }

        List<Contact> contactUpdates = new List<Contact>();
        for (Id contactId : contactIds) {
            AggregateResult ar = aggregatesByContactId.get(contactId);
            Contact contactUpdate = new Contact(Id = contactId);

            if (totalAmountField != null) {
                Decimal totalAmount = Decimal.valueOf(0);
                if (ar != null && ar.get('totalAmount') != null) {
                    totalAmount = ((Decimal) ar.get('totalAmount')).setScale(2);
                }
                contactUpdate.put(totalAmountField, totalAmount);
            }

            if (purchaseCountField != null) {
                Integer purchaseCount = 0;
                if (ar != null && ar.get('purchaseCount') != null) {
                    purchaseCount = Integer.valueOf(String.valueOf(ar.get('purchaseCount')));
                }
                contactUpdate.put(purchaseCountField, purchaseCount);
            }

            contactUpdates.add(contactUpdate);
        }

        if (!contactUpdates.isEmpty()) {
            Database.update(contactUpdates, false);
        }
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
