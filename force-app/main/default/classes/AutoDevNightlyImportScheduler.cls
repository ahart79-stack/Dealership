global with sharing class AutoDevNightlyImportScheduler implements Schedulable {
    @TestVisible private static final String JOB_NAME = 'Nightly Auto.dev Vehicle Import';
    @TestVisible private static final String CRON_EXPRESSION = '0 0 2 * * ?';

    global void execute(SchedulableContext context) {
        System.enqueueJob(new AutoDevNightlyImportJob());
    }

    public static String scheduleNightly() {
        for (CronTrigger existingJob : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
        ]) {
            System.abortJob(existingJob.Id);
        }

        return System.schedule(JOB_NAME, CRON_EXPRESSION, new AutoDevNightlyImportScheduler());
    }
}