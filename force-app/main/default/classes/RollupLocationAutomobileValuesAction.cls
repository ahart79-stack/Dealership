public with sharing class RollupLocationAutomobileValuesAction {
    public class Request {
        @InvocableVariable(label='Run Rollup')
        public Boolean runRollup;
    }

    public class Result {
        @InvocableVariable(label='Locations Updated')
        public Integer locationsUpdated;

        @InvocableVariable(label='Total Value')
        public Decimal totalValue;
    }

    @InvocableMethod(
        label='Rollup Automobile Values to Location'
        description='Sums Value__c on all Automobile__c records grouped by Location__c and writes the total to Location.Total_value_in_Automobiles__c.'
    )
    public static List<Result> run(List<Request> requests) {
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
        Decimal grandTotal = 0;
        for (Id locId : sumByLocation.keySet()) {
            Decimal locTotal = sumByLocation.get(locId);
            grandTotal += locTotal;
            toUpdate.add(new Schema.Location(
                Id = locId,
                Total_value_in_Automobiles__c = locTotal
            ));
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        Result result = new Result();
        result.locationsUpdated = toUpdate.size();
        result.totalValue = grandTotal;
        return new List<Result>{ result };
    }
}
