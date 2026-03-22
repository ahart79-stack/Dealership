import { LightningElement, track, wire } from 'lwc';
import getInventory from '@salesforce/apex/CurrentInventoryController.getInventory';
import { refreshApex } from '@salesforce/apex';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Record ID', fieldName: 'IdUrl', type: 'url', typeAttributes: { label: { fieldName: 'Id' } } },
    { label: 'Make', fieldName: 'Make__c' },
    { label: 'Year', fieldName: 'Year__c' },
    { label: 'Mileage', fieldName: 'Mileage__c', type: 'number' },
    { label: 'Days on Lot', fieldName: 'DaysOnLot', type: 'number' },
    { label: 'Value', fieldName: 'Value__c', type: 'currency' },
    { label: 'Dealership', fieldName: 'Dealer_Name__c' },
    { label: 'Type', fieldName: 'RecordTypeName' }
];

export default class CurrentInventory extends LightningElement {
    @track newAutos = [];
    @track usedAutos = [];
    @track error;
    @track searchTerm = '';
    wiredInventoryResult;
    columns = COLUMNS;

    get newAutosFiltered() {
        return this._filterRows(this.newAutos);
    }

    get usedAutosFiltered() {
        return this._filterRows(this.usedAutos);
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
    }

    _filterRows(rows) {
        if (!this.searchTerm) return rows;
        return rows.filter(r =>
            (r.Name && r.Name.toLowerCase().includes(this.searchTerm)) ||
            (r.Make__c && r.Make__c.toLowerCase().includes(this.searchTerm)) ||
            (r.Year__c && String(r.Year__c).includes(this.searchTerm)) ||
            (r.Dealer_Name__c && r.Dealer_Name__c.toLowerCase().includes(this.searchTerm)) ||
            (r.Color__c && r.Color__c.toLowerCase().includes(this.searchTerm))
        );
    }

    @wire(getInventory, { limitSize: 100 })
    wiredInventory({ error, data }) {
        this.wiredInventoryResult = { error, data };
        if (data) {
            this.error = undefined;
            this.newAutos = data
                .filter(a => a.RecordType && a.RecordType.DeveloperName === 'New')
                .map(a => this._mapRow(a));
            this.usedAutos = data
                .filter(a => a.RecordType && a.RecordType.DeveloperName === 'Used')
                .map(a => this._mapRow(a));
        } else if (error) {
            this.error = error;
            this.newAutos = [];
            this.usedAutos = [];
        }
    }

    handleRefresh() {
        if (this.wiredInventoryResult) {
            refreshApex(this.wiredInventoryResult);
        }
    }

    _mapRow(record) {
        return {
            ...record,
            IdUrl: record.Id ? '/' + record.Id : undefined,
            DaysOnLot: record.Number_of_Days_on_Lot__c,
            Dealer_Name__c: record.Type_of_Dealership__r ? record.Type_of_Dealership__r.Name : undefined,
            RecordTypeName: record.RecordType ? record.RecordType.DeveloperName : undefined
        };
    }
}
