global with sharing class NightlyAutomobileSalesScheduler implements Schedulable {
    @TestVisible private static final String JOB_NAME = 'Nightly Random Automobile Sales';
    @TestVisible private static final String CRON_EXPRESSION = '0 0 3 * * ?';

    global void execute(SchedulableContext context) {
        SellAutomobileController.sellNightlyAutos();
    }

    public static String scheduleNightly() {
        unscheduleAll();
        return System.schedule(JOB_NAME, CRON_EXPRESSION, new NightlyAutomobileSalesScheduler());
    }

    public static void unscheduleAll() {
        for (CronTrigger existingJob : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
        ]) {
            System.abortJob(existingJob.Id);
        }
    }
}