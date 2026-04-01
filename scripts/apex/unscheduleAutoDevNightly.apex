for (CronTrigger ct : [
    SELECT Id
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'Nightly Auto.dev Vehicle Import'
]) {
    System.abortJob(ct.Id);
}