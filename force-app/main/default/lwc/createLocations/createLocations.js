import { LightningElement, track } from 'lwc';
import createLocations from '@salesforce/apex/CreateLocationsController.createLocations';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateLocations extends LightningElement {
    @track loading = false;

    handleClick() {
        if (this.loading) return;
        this.loading = true;
        createLocations({ count: 10 })
            .then(result => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: result + ' locations created.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                const msg = (error && error.body && error.body.message)
                    ? error.body.message
                    : (error.message || JSON.stringify(error));
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error creating locations',
                    message: msg,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.loading = false;
            });
    }
}