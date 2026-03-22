import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getVehicleCountByLocation from '@salesforce/apex/InventoryAtLocationController.getVehicleCountByLocation';

export default class RefreshLocationVehicleCountsAction extends LightningElement {
    loading = true;
    hasRun = false;

    connectedCallback() {
        this.runRefresh();
    }

    runRefresh() {
        if (this.hasRun) {
            return;
        }
        this.hasRun = true;
        this.loading = true;

        getVehicleCountByLocation()
            .then((rows) => {
                const totalVehicles = rows.reduce((sum, row) => sum + row.vehicleCount, 0);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Vehicle counts refreshed',
                        message: `${rows.length} locations updated, ${totalVehicles} vehicles counted.`,
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((error) => {
                const message = error?.body?.message || error?.message || 'Unknown error';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Refresh failed',
                        message,
                        variant: 'error'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .finally(() => {
                this.loading = false;
            });
    }
}
