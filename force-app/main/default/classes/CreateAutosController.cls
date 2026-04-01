public with sharing class CreateAutosController {
    public class LocationOption {
        @AuraEnabled public String label;
        @AuraEnabled public Id value;

        public LocationOption(String label, Id value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<LocationOption> getLocations() {
        List<LocationOption> options = new List<LocationOption>();
        for (Schema.Location loc : [SELECT Id, Name FROM Location ORDER BY Name LIMIT 200]) {
            options.add(new LocationOption(loc.Name, loc.Id));
        }
        return options;
    }

    @AuraEnabled
    public static Integer createRandomAutos(Integer count, List<Id> selectedLocationIds) {
        try {
            if (count == null || count <= 0) count = 25;
            
            List<Automobile__c> autos = new List<Automobile__c>();
            String[] makes = new String[]{'Ford','Toyota','Kia','Volvo','GMC','Chevrolet','Buick'};
            String[] models = new String[]{'Sedan','SUV','Truck','Coupe','Wagon','Hatchback','Convertible','Van','Crossover','Sports'};
            String[] colors = new String[]{'Red','Black','White','Grey','Blue','Silver'};
            String[] recordTypes = new String[]{'New','Used'};
            String vinChars = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789';

            // Map each make to a corresponding dealership record.
            // Preferred naming is plain make (for example: Ford), while still
            // supporting legacy names like "Ford Dealership".
            Map<String, Id> makeToDealershipId = new Map<String, Id>();

            for (typeofdealership__c d : [SELECT Id, Name FROM typeofdealership__c WHERE Name IN :makes]) {
                makeToDealershipId.put(d.Name, d.Id);
            }

            List<String> legacyDealershipNames = new List<String>();
            for (String m : makes) {
                legacyDealershipNames.add(m + ' Dealership');
            }

            for (typeofdealership__c d : [SELECT Id, Name FROM typeofdealership__c WHERE Name IN :legacyDealershipNames]) {
                String key = d.Name.replace(' Dealership', '');
                if (!makeToDealershipId.containsKey(key)) {
                    makeToDealershipId.put(key, d.Id);
                }
            }

            // Create missing lookup records for any makes that don't yet have a dealership record
            Set<String> missingMakes = new Set<String>();
            for (String m : makes) {
                if (!makeToDealershipId.containsKey(m)) {
                    missingMakes.add(m);
                }
            }
            if (!missingMakes.isEmpty()) {
                List<typeofdealership__c> toInsert = new List<typeofdealership__c>();
                for (String m : missingMakes) {
                    toInsert.add(new typeofdealership__c(Name = m));
                }
                insert toInsert;
                for (typeofdealership__c d : toInsert) {
                    makeToDealershipId.put(d.Name, d.Id);
                }
            }

            Long timestamp = System.currentTimeMillis();
            Integer currentYear = System.today().year();
            Date today = System.today();
            List<Id> locationIds = new List<Id>();
            if (selectedLocationIds != null && !selectedLocationIds.isEmpty()) {
                for (Schema.Location loc : [SELECT Id FROM Location WHERE Id IN :selectedLocationIds LIMIT 200]) {
                    locationIds.add(loc.Id);
                }
            } else {
                for (Schema.Location loc : [SELECT Id FROM Location LIMIT 200]) {
                    locationIds.add(loc.Id);
                }
            }

            for (Integer i = 0; i < count; i++){
                String make = makes[Math.mod(i, makes.size())];
                String model = models[Math.mod(i, models.size())];
                String color = colors[Math.mod(i, colors.size())];
                String recordType = recordTypes[Math.mod(i, recordTypes.size())];
                
                Integer year = (recordType == 'New') ? currentYear : (currentYear - 1 - Math.mod(i, 10));
                Decimal value = Decimal.valueOf(15000 + Math.mod(i * 1234, 50000));
                Integer mileage = (recordType == 'New') ? Math.mod(i * 50, 1000) : (10000 + Math.mod(i * 15000, 140000));
                Decimal boughtPrice = (recordType == 'New')
                    ? (value * Decimal.valueOf(70)) / Decimal.valueOf(100)
                    : (value * Decimal.valueOf(78 + Math.mod(i * 3, 15))) / Decimal.valueOf(100);
                Integer daysAgo = Math.mod(Integer.valueOf(Math.abs(Math.mod(timestamp + (i * 7919), 2147483647))), 60);
                Date boughtDate = today.addDays(-daysAgo);
                
                // Generate random VIN (17 characters)
                String vin = '';
                for (Integer j = 0; j < 17; j++) {
                    Integer charIndex = Math.mod((i * 17 + j) * 7, vinChars.length());
                    vin += vinChars.substring(charIndex, charIndex + 1);
                }
                
                Automobile__c auto = new Automobile__c(
                    Name = make + ' ' + model + ' - ' + vin
                );
                auto.Year__c = String.valueOf(year);
                auto.Value__c = value;
                auto.Bought_Price__c = boughtPrice.setScale(2);
                auto.VIN__c = vin;
                auto.Mileage__c = mileage;
                auto.Bought__c = boughtDate;
                if (recordType == 'New') {
                    auto.Bought_Via__c = 'Factory';
                }
                auto.Make__c = make;
                auto.Color__c = color;
                auto.Original_Value__c = value;
                auto.Sales_Price__c = value;
                auto.Type_of_Dealership__c = makeToDealershipId.get(make);
                if (!locationIds.isEmpty()) {
                    Integer locationIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), locationIds.size());
                    auto.Location__c = locationIds[locationIndex];
                }
                auto.RecordTypeId = Schema.SObjectType.Automobile__c.getRecordTypeInfosByName().get(recordType).getRecordTypeId();
                
                autos.add(auto);
            }

            Integer created = 0;
            Database.SaveResult[] results = Database.insert(autos, false);
            for (Database.SaveResult r : results) {
                if (r.isSuccess()) {
                    created++;
                }
            }
            return created;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
}
