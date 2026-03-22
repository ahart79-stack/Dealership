import { LightningElement, track } from 'lwc';
import createRandomAutos from '@salesforce/apex/CreateAutosController.createRandomAutos';
import getLocations from '@salesforce/apex/CreateAutosController.getLocations';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateAutos extends LightningElement {
    @track loading = false;
    showLocationSelector = false;
    count = 25;
    locationOptions = [{ label: 'All', value: '__ALL__' }];
    selectedLocations = [];

    connectedCallback() {
        getLocations()
            .then((result) => {
                const options = (result || []).map((loc) => ({
                    label: loc.label,
                    value: loc.value
                }));
                this.locationOptions = [{ label: 'All', value: '__ALL__' }, ...options];
            })
            .catch((error) => {
                const msg = (error && error.body && error.body.message)
                    ? error.body.message
                    : (error.message || JSON.stringify(error));
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error loading locations',
                    message: msg,
                    variant: 'error'
                }));
            });
    }

    handleLocationChange(event) {
        const values = event.detail.value || [];
        if (values.includes('__ALL__')) {
            this.selectedLocations = ['__ALL__'];
            return;
        }
        this.selectedLocations = values;
    }

    handleClick() {
        console.log('Button clicked!');
        if (this.loading) return;
        this.showLocationSelector = true;
    }

    handleCancelSelection() {
        if (this.loading) return;
        this.showLocationSelector = false;
    }

    handleConfirmCreate() {
        if (this.loading) return;
        if (!this.selectedLocations || this.selectedLocations.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Select locations',
                message: 'Please select one or more locations, or select All.',
                variant: 'warning'
            }));
            return;
        }

        this.loading = true;
        console.log('Calling createRandomAutos with count:', this.count);
        
        createRandomAutos({
            count: this.count,
            selectedLocationIds: this.selectedLocations.includes('__ALL__') ? [] : this.selectedLocations
        })
            .then(result => {
                console.log('Success! Created:', result);
                this.showLocationSelector = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: result + ' automobiles created.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                console.error('Error:', error);
                const msg = (error && error.body && error.body.message) 
                    ? error.body.message 
                    : (error.message || JSON.stringify(error));
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error creating automobiles',
                    message: msg,
                    variant: 'error'
                }));
            })
            .finally(() => { 
                this.loading = false; 
                console.log('Call complete');
            });
    }
}
