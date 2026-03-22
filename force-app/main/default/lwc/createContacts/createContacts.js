import { LightningElement, track } from 'lwc';
import createRandomContacts from '@salesforce/apex/CreateContactsController.createRandomContacts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CreateContacts extends LightningElement {
    @track loading = false;
    count = 25;

    handleClick() {
        console.log('Button clicked!');
        if (this.loading) return;
        this.loading = true;
        console.log('Calling createRandomContacts with count:', this.count);
        
        createRandomContacts({ count: this.count })
            .then(result => {
                console.log('Success! Created:', result);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: result + ' contacts created.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                console.error('Error:', error);
                const msg = (error && error.body && error.body.message) 
                    ? error.body.message 
                    : (error.message || JSON.stringify(error));
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error creating contacts',
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
