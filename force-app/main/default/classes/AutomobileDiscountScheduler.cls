/**
 * Schedulable class that applies automobile value discounts nightly.
 *
 * To schedule via Setup > Apex Classes > Schedule Apex, or run once in Developer Console:
 *   System.schedule('Nightly Automobile Discounts', '0 0 2 * * ?', new AutomobileDiscountScheduler());
 *
 * Cron breakdown: runs at 2:00 AM every day.
 * To reschedule to a different time change the cron expression above.
 */
global class AutomobileDiscountScheduler implements Schedulable {
    global void execute(SchedulableContext ctx) {
        AutomobileSales30_90Controller.applyDiscounts();
    }
}
