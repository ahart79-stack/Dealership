import { LightningElement, track } from 'lwc';
import sellRandomAutos from '@salesforce/apex/SellAutomobileController.sellRandomAutos';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SellAutomobile extends LightningElement {
	@track loading = false;

	handleSellClick() {
		if (this.loading) {
			return;
		}

		this.loading = true;
		sellRandomAutos({ count: 10 })
			.then(result => {
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Success',
						message: result + ' automobiles sold with random sold dates.',
						variant: 'success'
					})
				);
			})
			.catch(error => {
				const msg = (error && error.body && error.body.message)
					? error.body.message
					: (error.message || JSON.stringify(error));
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Error selling automobiles',
						message: msg,
						variant: 'error'
					})
				);
			})
			.finally(() => {
				this.loading = false;
			});
	}
}