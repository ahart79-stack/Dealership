import { LightningElement, api } from 'lwc';
import getLocationInventory from '@salesforce/apex/LocationInventoryPageController.getLocationInventory';

const CURRENT_COLUMNS = [
	{ label: 'Vehicle', fieldName: 'name' },
	{ label: 'Make', fieldName: 'make' },
	{ label: 'Year', fieldName: 'year' },
	{ label: 'Mileage', fieldName: 'mileage', type: 'number' },
	{ label: 'Value', fieldName: 'value', type: 'currency' }
];

const SOLD_COLUMNS = [
	{ label: 'Vehicle', fieldName: 'name' },
	{ label: 'Make', fieldName: 'make' },
	{ label: 'Year', fieldName: 'year' },
	{ label: 'Sold Date', fieldName: 'soldDate', type: 'date' },
	{ label: 'Value', fieldName: 'value', type: 'currency' }
];

export default class LocationInventoryTabs extends LightningElement {
	@api recordId;
	locationName;
	currentColumns = CURRENT_COLUMNS;
	soldColumns = SOLD_COLUMNS;
	currentInventory = [];
	soldInventory = [];
	loading = false;
	errorMessage;

	connectedCallback() {
		this.loadData();
	}

	@api
	refreshData() {
		this.loadData();
	}

	get currentCount() {
		return this.currentInventory.length;
	}

	get soldCount() {
		return this.soldInventory.length;
	}

	get currentTabLabel() {
		return `Current Inventory (${this.currentCount})`;
	}

	get soldTabLabel() {
		return `Sold Cars (${this.soldCount})`;
	}

	get hasCurrentInventory() {
		return this.currentCount > 0;
	}

	get hasSoldInventory() {
		return this.soldCount > 0;
	}

	loadData() {
		if (!this.recordId) {
			return;
		}

		this.loading = true;
		getLocationInventory({ locationId: this.recordId })
			.then((data) => {
				this.locationName = data?.locationName;
				this.currentInventory = data?.currentInventory || [];
				this.soldInventory = data?.soldInventory || [];
				this.errorMessage = undefined;
			})
			.catch((error) => {
				this.currentInventory = [];
				this.soldInventory = [];
				this.errorMessage = error?.body?.message || error?.message || 'Unable to load inventory for this location.';
			})
			.finally(() => {
				this.loading = false;
			});
	}
}
