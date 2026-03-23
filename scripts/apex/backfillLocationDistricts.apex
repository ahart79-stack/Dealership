Decimal DISTRICT_RADIUS_MILES = 100;
Decimal EARTH_RADIUS_MILES = 3958.756;

List<String> districtValues = new List<String>();
for (Schema.PicklistEntry entry : Schema.SObjectType.Location.fields.getMap().get('District__c').getDescribe().getPicklistValues()) {
    if (entry.isActive()) {
        districtValues.add(entry.getValue());
    }
}

List<Schema.Location> locations = [
    SELECT Id, Name, Latitude, Longitude, District__c
    FROM Location
    WHERE Latitude != null AND Longitude != null
    ORDER BY Name
    LIMIT 10000
];

List<String> computedDistricts = new List<String>();
for (Integer i = 0; i < locations.size(); i++) {
    computedDistricts.add(null);
}

Integer districtNumber = 1;
for (Integer i = 0; i < locations.size(); i++) {
    if (computedDistricts[i] != null) {
        continue;
    }
    if (districtNumber > districtValues.size()) {
        throw new AuraHandledException('Location.District__c does not have enough picklist values for the existing location districts.');
    }

    String districtValue = districtValues[districtNumber - 1];
    List<Integer> queue = new List<Integer>{ i };
    computedDistricts[i] = districtValue;

    while (!queue.isEmpty()) {
        Integer currentIndex = queue.remove(0);
        for (Integer candidateIndex = 0; candidateIndex < locations.size(); candidateIndex++) {
            if (computedDistricts[candidateIndex] != null) {
                continue;
            }
            if (distanceInMiles(locations[currentIndex], locations[candidateIndex], EARTH_RADIUS_MILES) <= DISTRICT_RADIUS_MILES) {
                computedDistricts[candidateIndex] = districtValue;
                queue.add(candidateIndex);
            }
        }
    }

    districtNumber++;
}

List<Schema.Location> updates = new List<Schema.Location>();
for (Integer i = 0; i < locations.size(); i++) {
    if (locations[i].District__c == computedDistricts[i]) {
        continue;
    }
    updates.add(new Schema.Location(Id = locations[i].Id, District__c = computedDistricts[i]));
}

Database.SaveResult[] results = Database.update(updates, false);
Integer updated = 0;
Integer failed = 0;
for (Database.SaveResult result : results) {
    if (result.isSuccess()) {
        updated++;
    } else {
        failed++;
        for (Database.Error err : result.getErrors()) {
            System.debug('Failed to update Location district: ' + err.getMessage());
        }
    }
}

System.debug('Location district backfill complete. Evaluated: ' + locations.size() + ', Updated: ' + updated + ', Failed: ' + failed);

public static Decimal distanceInMiles(Schema.Location leftLocation, Schema.Location rightLocation, Decimal earthRadiusMiles) {
    Decimal leftLatitudeRadians = degreesToRadians(leftLocation.Latitude);
    Decimal leftLongitudeRadians = degreesToRadians(leftLocation.Longitude);
    Decimal rightLatitudeRadians = degreesToRadians(rightLocation.Latitude);
    Decimal rightLongitudeRadians = degreesToRadians(rightLocation.Longitude);

    Decimal latitudeDelta = rightLatitudeRadians - leftLatitudeRadians;
    Decimal longitudeDelta = rightLongitudeRadians - leftLongitudeRadians;
    Decimal haversine = square(Math.sin((Double)(latitudeDelta / 2)))
        + Math.cos((Double)leftLatitudeRadians)
        * Math.cos((Double)rightLatitudeRadians)
        * square(Math.sin((Double)(longitudeDelta / 2)));
    Double centralAngle = 2 * Math.atan2(Math.sqrt((Double)haversine), Math.sqrt(1 - (Double)haversine));

    return earthRadiusMiles * Decimal.valueOf(centralAngle);
}

public static Decimal degreesToRadians(Decimal degrees) {
    return degrees * Decimal.valueOf(Math.PI) / 180;
}

public static Decimal square(Double value) {
    return Decimal.valueOf(value * value);
}