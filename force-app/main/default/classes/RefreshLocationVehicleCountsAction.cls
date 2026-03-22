public with sharing class RefreshLocationVehicleCountsAction {
    public class Request {
        @InvocableVariable(label='Run Refresh')
        public Boolean runRefresh;
    }

    public class Result {
        @InvocableVariable(label='Locations Processed')
        public Integer locationsProcessed;

        @InvocableVariable(label='Total Vehicles')
        public Integer totalVehicles;
    }

    @InvocableMethod(label='Refresh Location Vehicle Counts' description='Counts Automobile records by Location and writes to Location.Number_of_vehicles__c.')
    public static List<Result> run(List<Request> requests) {
        List<InventoryAtLocationController.LocationInventoryRow> rows =
            InventoryAtLocationController.getVehicleCountByLocation();

        Integer totalVehicles = 0;
        for (InventoryAtLocationController.LocationInventoryRow row : rows) {
            totalVehicles += row.vehicleCount;
        }

        Result result = new Result();
        result.locationsProcessed = rows.size();
        result.totalVehicles = totalVehicles;
        return new List<Result>{ result };
    }
}
