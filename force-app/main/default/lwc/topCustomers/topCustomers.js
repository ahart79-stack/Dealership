import { LightningElement } from 'lwc';
import getTopCustomers from '@salesforce/apex/TopCustomersController.getTopCustomers';

const COLUMNS = [
	{
		label: 'Customer',
		fieldName: 'contactNameUrl',
		type: 'url',
		typeAttributes: {
			label: { fieldName: 'contactName' }
		}
	},
	{ label: 'Email', fieldName: 'email', type: 'email' },
	{ label: 'Phone', fieldName: 'phone', type: 'phone' },
	{ label: 'Purchases', fieldName: 'purchaseCount', type: 'number' },
	{ label: 'Total Spent', fieldName: 'totalSpent', type: 'currency' },
	{ label: 'Last Purchase', fieldName: 'lastPurchaseDate', type: 'date' }
];

export default class TopCustomers extends LightningElement {
	columns = COLUMNS;
	rows = [];
	error;
	loading = false;

	get hasRows() {
		return this.rows.length > 0;
	}

	connectedCallback() {
		this.loadTopCustomers();
	}

	loadTopCustomers() {
		this.loading = true;
		getTopCustomers({ limitSize: 10 })
			.then((data) => {
				this.rows = (data || []).map((row) => ({
					...row,
					contactNameUrl: row.contactId ? '/' + row.contactId : undefined
				}));
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