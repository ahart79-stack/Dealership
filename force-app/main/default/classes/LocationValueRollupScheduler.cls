global with sharing class LocationValueRollupScheduler implements Schedulable {
    @TestVisible private static final String JOB_NAME_PREFIX = 'Hourly Location Value Rollup';

    global void execute(SchedulableContext context) {
        RollupLocationAutomobileValuesAction.run(
            new List<RollupLocationAutomobileValuesAction.Request>{
                new RollupLocationAutomobileValuesAction.Request()
            }
        );

        // Re-schedule for the next hour
        Datetime nextRun = Datetime.now().addHours(1);
        String cron = nextRun.second()  + ' ' +
                      nextRun.minute()  + ' ' +
                      nextRun.hour()    + ' ' +
                      nextRun.day()     + ' ' +
                      nextRun.month()   + ' ' +
                      '? ' +
                      nextRun.year();

        String jobName = JOB_NAME_PREFIX + ' ' + nextRun.formatGmt('yyyy-MM-dd HH:mm');
        System.schedule(jobName, cron, new LocationValueRollupScheduler());
    }

    public static String scheduleNow() {
        // Abort any existing hourly rollup jobs
        for (CronTrigger existing : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :JOB_NAME_PREFIX + '%'
        ]) {
            System.abortJob(existing.Id);
        }

        // Schedule the first run 1 hour from now
        Datetime firstRun = Datetime.now().addHours(1);
        String cron = firstRun.second() + ' ' +
                      firstRun.minute() + ' ' +
                      firstRun.hour()   + ' ' +
                      firstRun.day()    + ' ' +
                      firstRun.month()  + ' ' +
                      '? ' +
                      firstRun.year();

        String jobName = JOB_NAME_PREFIX + ' ' + firstRun.formatGmt('yyyy-MM-dd HH:mm');
        return System.schedule(jobName, cron, new LocationValueRollupScheduler());
    }

    public static void unscheduleAll() {
        for (CronTrigger existing : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :JOB_NAME_PREFIX + '%'
        ]) {
            System.abortJob(existing.Id);
        }
    }
}
