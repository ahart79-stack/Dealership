import { LightningElement } from 'lwc';
import getVehicleCountByLocation from '@salesforce/apex/InventoryAtLocationController.getVehicleCountByLocation';
import getContactsWithMoreThanTwoPurchases from '@salesforce/apex/InventoryAtLocationController.getContactsWithMoreThanTwoPurchases';

const LOCATION_COLUMNS = [
	{ label: 'Location', fieldName: 'locationName' },
	{ label: 'Vehicle Count', fieldName: 'vehicleCount', type: 'number' }
];

const CONTACT_COLUMNS = [
	{ label: 'Contact', fieldName: 'contactName' },
	{ label: 'Email', fieldName: 'email', type: 'email' },
	{ label: 'Phone', fieldName: 'phone', type: 'phone' },
	{ label: 'Purchase Count', fieldName: 'purchaseCount', type: 'number' }
];

export default class InventoryatLocation extends LightningElement {
	locationColumns = LOCATION_COLUMNS;
	contactColumns = CONTACT_COLUMNS;
	locationRows = [];
	contactRows = [];
	error;
	loading = false;

	connectedCallback() {
		this.refreshCounts();
	}

	refreshCounts() {
		this.loading = true;
		Promise.all([getVehicleCountByLocation(), getContactsWithMoreThanTwoPurchases()])
			.then(([locationData, contactData]) => {
				this.locationRows = locationData;
				this.contactRows = contactData;
				this.error = undefined;
			})
			.catch((error) => {
				this.locationRows = [];
				this.contactRows = [];
				this.error = error;
			})
			.finally(() => {
				this.loading = false;
			});
	}
}