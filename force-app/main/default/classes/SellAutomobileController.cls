public with sharing class SellAutomobileController {
    @AuraEnabled
    public static Integer sellRandomAutos(Integer count) {
        try {
            if (count == null || count <= 0) {
                count = 10;
            }

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
            Schema.DisplayType soldDateType = soldDateField == null
                ? null
                : fieldMap.get(soldDateField).getDescribe().getType();
            Schema.DisplayType soldFlagType = soldFlagField == null
                ? null
                : fieldMap.get(soldFlagField).getDescribe().getType();

            Integer querySize = Math.max(count * 5, 50);
            String selectFields = 'Id, Bought__c, Value__c';
            if (boughtPriceField != null) {
                selectFields += ', ' + boughtPriceField;
            }

            String soql = 'SELECT ' + selectFields +
                ' FROM Automobile__c' +
                ' WHERE Bought__c != NULL' +
                (soldRecordTypeId != null ? ' AND RecordTypeId != \'' + soldRecordTypeId + '\'' : '') +
                ' ORDER BY CreatedDate DESC' +
                ' LIMIT ' + querySize;
            List<Automobile__c> candidates = Database.query(soql);

            if (candidates.isEmpty()) {
                return 0;
            }

            Integer target = Math.min(count, candidates.size());
            Set<Integer> selectedIndexes = new Set<Integer>();
            List<Automobile__c> updates = new List<Automobile__c>();
            Integer attempts = 0;

            while (updates.size() < target && attempts < candidates.size() * 4) {
                Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), candidates.size());
                attempts++;
                if (selectedIndexes.contains(idx)) {
                    continue;
                }
                selectedIndexes.add(idx);

                Automobile__c source = candidates[idx];
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
                // RecordType is changed in a separate DML pass below

                updates.add(row);
            }

            if (updates.isEmpty()) {
                return 0;
            }

            Integer soldCount = 0;
            List<String> errors = new List<String>();
            Database.SaveResult[] results = Database.update(updates, false);
            List<Automobile__c> rtUpdates = new List<Automobile__c>();
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    soldCount++;
                    if (soldRecordTypeId != null) {
                        rtUpdates.add(new Automobile__c(Id = updates[i].Id, RecordTypeId = soldRecordTypeId));
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
            if (soldCount == 0 && !errors.isEmpty()) {
                throw new AuraHandledException('No cars sold. Errors: ' + String.join(errors, '; '));
            }
            return soldCount;
        } catch (Exception e) {
            throw e;
        }
    }

    private static Date randomSoldDate(Date boughtDate) {
        Date today = System.today();
        Date earliest = today.addDays(-59);
        if (boughtDate != null && boughtDate > earliest) {
            earliest = boughtDate;
        }

        Integer span = Math.max(0, earliest.daysBetween(today));
        Integer offset = span == 0 ? 0 : Math.mod(Math.abs(Crypto.getRandomInteger()), span + 1);
        return earliest.addDays(offset);
    }

    private static String firstExisting(Map<String, Schema.SObjectField> fieldMap, List<String> candidates) {
        for (String fieldName : candidates) {
            if (fieldMap.containsKey(fieldName)) {
                return fieldName;
            }
        }
        return null;
    }
}
