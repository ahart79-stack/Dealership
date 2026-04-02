public with sharing class CreateLocationsController {

    private static final Decimal DISTRICT_RADIUS_MILES = 100;
    private static final Decimal EARTH_RADIUS_MILES = 3958.756;

    // Northeast US zip codes curated so each is ~50+ miles from its neighbors.
    // Format: zip, city, state abbreviation, latitude, longitude
    private static final List<String[]> NORTHEAST_ZIPS = new List<String[]>{
        new String[]{'04101', 'Portland',        'ME', '43.6591', '-70.2568'},
        new String[]{'04401', 'Bangor',           'ME', '44.8012', '-68.7778'},
        new String[]{'03301', 'Concord',          'NH', '43.2081', '-71.5376'},
        new String[]{'03801', 'Portsmouth',       'NH', '43.0718', '-70.7626'},
        new String[]{'05401', 'Burlington',       'VT', '44.4759', '-73.2121'},
        new String[]{'05701', 'Rutland',          'VT', '43.6106', '-72.9726'},
        new String[]{'01103', 'Springfield',      'MA', '42.1015', '-72.5898'},
        new String[]{'01201', 'Pittsfield',       'MA', '42.4501', '-73.2590'},
        new String[]{'02101', 'Boston',           'MA', '42.3601', '-71.0589'},
        new String[]{'01901', 'Lynn',             'MA', '42.4668', '-70.9495'},
        new String[]{'02740', 'New Bedford',      'MA', '41.6362', '-70.9342'},
        new String[]{'02840', 'Newport',          'RI', '41.4901', '-71.3128'},
        new String[]{'06103', 'Hartford',         'CT', '41.7658', '-72.6851'},
        new String[]{'06901', 'Stamford',         'CT', '41.0534', '-73.5387'},
        new String[]{'06770', 'Naugatuck',        'CT', '41.4851', '-73.0512'},
        new String[]{'10001', 'New York City',    'NY', '40.7484', '-73.9967'},
        new String[]{'12601', 'Poughkeepsie',     'NY', '41.7004', '-73.9209'},
        new String[]{'12901', 'Plattsburgh',      'NY', '44.6995', '-73.4529'},
        new String[]{'13201', 'Syracuse',         'NY', '43.0481', '-76.1474'},
        new String[]{'14201', 'Buffalo',          'NY', '42.8864', '-78.8784'},
        new String[]{'14801', 'Corning',          'NY', '42.1431', '-77.0547'},
        new String[]{'07102', 'Newark',           'NJ', '40.7357', '-74.1724'},
        new String[]{'08401', 'Atlantic City',    'NJ', '39.3643', '-74.4229'},
        new String[]{'08608', 'Trenton',          'NJ', '40.2171', '-74.7429'},
        new String[]{'17101', 'Harrisburg',       'PA', '40.2732', '-76.8867'},
        new String[]{'19103', 'Philadelphia',     'PA', '39.9526', '-75.1652'},
        new String[]{'16501', 'Erie',             'PA', '42.1292', '-80.0851'},
        new String[]{'18503', 'Scranton',         'PA', '41.4090', '-75.6624'}
    };

    private static final String[] PREFIXES = new String[]{
        'Northeast', 'Tri-State', 'Colonial', 'Patriot', 'Pilgrim',
        'Harbor', 'Coastal', 'Yankee', 'Heritage', 'Landmark',
        'Pinnacle', 'Premier', 'Liberty', 'Mayflower', 'Granite',
        'Maple', 'Bayshore', 'Atlantic', 'Berkshire', 'Capital'
    };

    private static final String[] SUFFIXES = new String[]{
        'Auto Group', 'Motor Cars', 'Automotive', 'Auto Center',
        'Car Dealership', 'Motors', 'Auto Sales', 'Auto Mall',
        'Vehicle Group', 'Auto World'
    };

    private static final String[] STREET_NAMES = new String[]{
        'Main', 'Maple', 'Oak', 'Cedar', 'Pine', 'River', 'Lake',
        'Park', 'Market', 'Liberty', 'Washington', 'Franklin', 'Broad',
        'Highland', 'Prospect', 'Union', 'Elm', 'Center', 'Summit', 'Bay'
    };

    private static final String[] STREET_TYPES = new String[]{
        'St', 'Ave', 'Rd', 'Blvd', 'Ln', 'Dr', 'Way', 'Pl'
    };

    private static final String[] MANAGER_FIRST_NAMES = new String[]{
        'Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Avery', 'Parker',
        'Cameron', 'Drew', 'Quinn', 'Skyler', 'Logan', 'Reese', 'Rowan', 'Hayden'
    };

    private static final String[] MANAGER_LAST_NAMES = new String[]{
        'Bennett', 'Carter', 'Davis', 'Ellis', 'Foster', 'Griffin', 'Hayes', 'Jordan',
        'Kennedy', 'Morris', 'Perry', 'Reed', 'Sawyer', 'Turner', 'Walker', 'Young'
    };

    @AuraEnabled
    public static Integer createLocations(Integer count) {
        try {
            if (count == null || count <= 0) {
                count = 10;
            }
            count = Math.min(count, NORTHEAST_ZIPS.size());

            Long ts = System.currentTimeMillis();
            Map<String, Schema.SObjectField> locationFields = Schema.SObjectType.Location.fields.getMap();
            String accountLookupField = null;
            if (locationFields.containsKey('Account__c')) {
                accountLookupField = 'Account__c';
            } else if (locationFields.containsKey('AccountId')) {
                accountLookupField = 'AccountId';
            }
            List<String> districtValues = new List<String>();
            if (locationFields.containsKey('District__c')) {
                for (Schema.PicklistEntry entry : locationFields.get('District__c').getDescribe().getPicklistValues()) {
                    if (entry.isActive()) {
                        districtValues.add(entry.getValue());
                    }
                }
            }

            // Shuffle the zip list deterministically using a timestamp seed
            List<String[]> pool = new List<String[]>(NORTHEAST_ZIPS);
            for (Integer i = pool.size() - 1; i > 0; i--) {
                Integer j = Math.mod(Math.abs(Crypto.getRandomInteger()), i + 1);
                String[] tmp = pool[i];
                pool[i] = pool[j];
                pool[j] = tmp;
            }

            List<String[]> selectedZips = new List<String[]>();
            List<String> locationNames = new List<String>();
            List<String> streetAddresses = new List<String>();
            for (Integer i = 0; i < count; i++) {
                String[] zip = pool[i];
                String prefix = PREFIXES[Math.mod(i + (Integer)Math.mod(ts, PREFIXES.size()), PREFIXES.size())];
                String suffix = SUFFIXES[Math.mod(i, SUFFIXES.size())];
                String name = prefix + ' ' + zip[2] + ' ' + suffix;
                Integer streetNumber = 100 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9800);
                String streetName = STREET_NAMES[Math.mod(Math.abs(Crypto.getRandomInteger()), STREET_NAMES.size())];
                String streetType = STREET_TYPES[Math.mod(Math.abs(Crypto.getRandomInteger()), STREET_TYPES.size())];
                String street = String.valueOf(streetNumber) + ' ' + streetName + ' ' + streetType;
                selectedZips.add(zip);
                locationNames.add(name);
                streetAddresses.add(street);
            }
            List<String> districts = buildDistrictAssignments(selectedZips, districtValues);

            List<Account> accountsToCreate = new List<Account>();
            for (Integer i = 0; i < count; i++) {
                String[] zip = selectedZips[i];
                Account acct = new Account();
                acct.Name = locationNames[i];
                acct.BillingStreet = streetAddresses[i];
                acct.BillingCity = zip[1];
                acct.BillingStateCode = zip[2];
                acct.BillingPostalCode = zip[0];
                acct.BillingCountryCode = 'US';
                accountsToCreate.add(acct);
            }
            Database.SaveResult[] accountResults = Database.insert(accountsToCreate, false);

            Id managerContactRecordTypeId = resolveManagerContactRecordTypeId();
            List<Contact> managersToCreate = new List<Contact>();
            for (Integer i = 0; i < count; i++) {
                String[] zip = selectedZips[i];
                String firstName = MANAGER_FIRST_NAMES[Math.mod(Math.abs(Crypto.getRandomInteger()), MANAGER_FIRST_NAMES.size())];
                String lastName = MANAGER_LAST_NAMES[Math.mod(Math.abs(Crypto.getRandomInteger()), MANAGER_LAST_NAMES.size())];

                Contact manager = new Contact();
                manager.FirstName = firstName;
                manager.LastName = lastName;
                manager.RecordTypeId = managerContactRecordTypeId;
                manager.Phone = '555-' + String.valueOf(100 + Math.mod(Math.abs(Crypto.getRandomInteger()), 900))
                    + '-' + String.valueOf(1000 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9000));
                manager.MailingCity = zip[1];
                manager.MailingStateCode = zip[2];
                manager.MailingPostalCode = zip[0];
                manager.MailingCountryCode = 'US';
                if (accountResults[i].isSuccess()) {
                    manager.AccountId = accountResults[i].getId();
                }
                managersToCreate.add(manager);
            }
            Database.SaveResult[] managerResults = Database.insert(managersToCreate, false);

            List<Schema.Location> locations = new List<Schema.Location>();
            for (Integer i = 0; i < count; i++) {
                String[] zip = selectedZips[i];
                String name = locationNames[i];

                Schema.Location loc = new Schema.Location();
                loc.Name             = name;
                loc.LocationType     = 'Site';
                loc.IsInventoryLocation = true;
                loc.Description      = zip[1] + ', ' + zip[2] + ' ' + zip[0];
                loc.Latitude         = Decimal.valueOf(zip[3]);
                loc.Longitude        = Decimal.valueOf(zip[4]);
                if (locationFields.containsKey('Street__c')) {
                    loc.put('Street__c', streetAddresses[i]);
                }
                if (locationFields.containsKey('City__c')) {
                    loc.put('City__c', zip[1]);
                }
                if (locationFields.containsKey('State__c')) {
                    loc.put('State__c', zip[2]);
                }
                if (locationFields.containsKey('Zip_Code__c')) {
                    loc.put('Zip_Code__c', zip[0]);
                }
                if (locationFields.containsKey('District__c')) {
                    loc.put('District__c', districts[i]);
                }
                if (accountLookupField != null && accountResults[i].isSuccess()) {
                    loc.put(accountLookupField, accountResults[i].getId());
                }
                if (locationFields.containsKey('Location_Manager__c') && managerResults[i].isSuccess()) {
                    loc.put('Location_Manager__c', managerResults[i].getId());
                }
                locations.add(loc);
            }

            Integer created = 0;
            Database.SaveResult[] results = Database.insert(locations, false);
            for (Database.SaveResult sr : results) {
                if (sr.isSuccess()) {
                    created++;
                }
            }
            return created;

        } catch (Exception e) {
            throw new AuraHandledException('Error creating locations: ' + e.getMessage());
        }
    }

    private static List<String> buildDistrictAssignments(List<String[]> selectedZips, List<String> districtValues) {
        List<String> districts = new List<String>();
        for (Integer i = 0; i < selectedZips.size(); i++) {
            districts.add(null);
        }
        if (districtValues.isEmpty()) {
            return districts;
        }

        Integer districtNumber = 1;
        for (Integer i = 0; i < selectedZips.size(); i++) {
            if (districts[i] != null) {
                continue;
            }

            if (districtNumber > districtValues.size()) {
                throw new AuraHandledException('Location.District__c does not have enough picklist values for the generated districts.');
            }

            String districtName = districtValues[districtNumber - 1];
            List<Integer> queue = new List<Integer>{ i };
            districts[i] = districtName;

            while (!queue.isEmpty()) {
                Integer currentIndex = queue.remove(0);
                for (Integer candidateIndex = 0; candidateIndex < selectedZips.size(); candidateIndex++) {
                    if (districts[candidateIndex] != null) {
                        continue;
                    }
                    if (distanceInMiles(selectedZips[currentIndex], selectedZips[candidateIndex]) <= DISTRICT_RADIUS_MILES) {
                        districts[candidateIndex] = districtName;
                        queue.add(candidateIndex);
                    }
                }
            }

            districtNumber++;
        }

        return districts;
    }

    private static Decimal distanceInMiles(String[] leftZip, String[] rightZip) {
        Decimal leftLatitudeRadians = degreesToRadians(Decimal.valueOf(leftZip[3]));
        Decimal leftLongitudeRadians = degreesToRadians(Decimal.valueOf(leftZip[4]));
        Decimal rightLatitudeRadians = degreesToRadians(Decimal.valueOf(rightZip[3]));
        Decimal rightLongitudeRadians = degreesToRadians(Decimal.valueOf(rightZip[4]));

        Decimal latitudeDelta = rightLatitudeRadians - leftLatitudeRadians;
        Decimal longitudeDelta = rightLongitudeRadians - leftLongitudeRadians;
        Decimal haversine = square(Math.sin((Double)(latitudeDelta / 2)))
            + Math.cos((Double)leftLatitudeRadians)
            * Math.cos((Double)rightLatitudeRadians)
            * square(Math.sin((Double)(longitudeDelta / 2)));
        Double centralAngle = 2 * Math.atan2(Math.sqrt((Double)haversine), Math.sqrt(1 - (Double)haversine));

        return EARTH_RADIUS_MILES * Decimal.valueOf(centralAngle);
    }

    private static Decimal degreesToRadians(Decimal degrees) {
        return degrees * Decimal.valueOf(Math.PI) / 180;
    }

    private static Decimal square(Double value) {
        return Decimal.valueOf(value * value);
    }

    private static Id resolveManagerContactRecordTypeId() {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact' AND DeveloperName = 'Manager'
            LIMIT 1
        ];
        if (recordTypes.isEmpty()) {
            throw new AuraHandledException('Contact record type Manager is required before creating locations.');
        }

        return recordTypes[0].Id;
    }
}
