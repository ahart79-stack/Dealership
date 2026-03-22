import { LightningElement } from 'lwc';
import getVehicleCountByLocation from '@salesforce/apex/InventoryAtLocationController.getVehicleCountByLocation';

const COLUMNS = [
	{ label: 'Location', fieldName: 'locationName' },
	{ label: 'Vehicle Count', fieldName: 'vehicleCount', type: 'number' }
];

export default class InventoryatLocation extends LightningElement {
	columns = COLUMNS;
	rows = [];
	error;
	loading = false;

	connectedCallback() {
		this.refreshCounts();
	}

	refreshCounts() {
		this.loading = true;
		getVehicleCountByLocation()
			.then((data) => {
				this.rows = data;
				this.error = undefined;
			})
			.catch((error) => {
				this.rows = [];
				this.error = error;
			})
			.finally(() => {
				this.loading = false;
			});
	}
}