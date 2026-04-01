try {
    AutoDevVehicleImportService.ImportResult result = AutoDevVehicleImportService.importNightlyListings();
    System.debug('AUTO_DEV_IMPORT requested=' + result.requested +
        ' imported=' + result.imported +
        ' skippedExisting=' + result.skippedExisting +
        ' skippedMissingVin=' + result.skippedMissingVin +
        ' failed=' + result.failed);
    for (String msg : result.failureMessages) {
        System.debug('AUTO_DEV_FAILURE: ' + msg);
    }
} catch (Exception ex) {
    System.debug('AUTO_DEV_IMPORT_ERROR ' + ex.getMessage());
    throw ex;
}