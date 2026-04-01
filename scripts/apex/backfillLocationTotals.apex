// Backfill Total_value_in_Automobiles__c on all Location records
Map<Id, Decimal> sumByLocation = new Map<Id, Decimal>();

for (Schema.Location loc : [SELECT Id FROM Location]) {
    sumByLocation.put(loc.Id, 0);
}

for (AggregateResult ar : [
    SELECT Location__c locId, SUM(Value__c) total
    FROM Automobile__c
    WHERE Location__c != null
    GROUP BY Location__c
]) {
    Id locId = (Id) ar.get('locId');
    Decimal total = (Decimal) ar.get('total');
    if (sumByLocation.containsKey(locId)) {
        sumByLocation.put(locId, total != null ? total : 0);
    }
}

List<Schema.Location> toUpdate = new List<Schema.Location>();
for (Id locId : sumByLocation.keySet()) {
    toUpdate.add(new Schema.Location(
        Id = locId,
        Total_value_in_Automobiles__c = sumByLocation.get(locId)
    ));
}

update toUpdate;
System.debug('BACKFILL_LOCATION_TOTALS updated=' + toUpdate.size());
