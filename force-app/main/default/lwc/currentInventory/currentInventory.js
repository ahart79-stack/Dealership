import { LightningElement, track, wire } from 'lwc';
import getInventory from '@salesforce/apex/CurrentInventoryController.getInventory';
import { refreshApex } from '@salesforce/apex';

const STATE_NAME_BY_CODE = {
    AL: 'alabama', AK: 'alaska', AZ: 'arizona', AR: 'arkansas', CA: 'california',
    CO: 'colorado', CT: 'connecticut', DE: 'delaware', FL: 'florida', GA: 'georgia',
    HI: 'hawaii', ID: 'idaho', IL: 'illinois', IN: 'indiana', IA: 'iowa',
    KS: 'kansas', KY: 'kentucky', LA: 'louisiana', ME: 'maine', MD: 'maryland',
    MA: 'massachusetts', MI: 'michigan', MN: 'minnesota', MS: 'mississippi', MO: 'missouri',
    MT: 'montana', NE: 'nebraska', NV: 'nevada', NH: 'new hampshire', NJ: 'new jersey',
    NM: 'new mexico', NY: 'new york', NC: 'north carolina', ND: 'north dakota', OH: 'ohio',
    OK: 'oklahoma', OR: 'oregon', PA: 'pennsylvania', RI: 'rhode island', SC: 'south carolina',
    SD: 'south dakota', TN: 'tennessee', TX: 'texas', UT: 'utah', VT: 'vermont',
    VA: 'virginia', WA: 'washington', WV: 'west virginia', WI: 'wisconsin', WY: 'wyoming'
};

const COLUMNS = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Record ID', fieldName: 'IdUrl', type: 'url', typeAttributes: { label: { fieldName: 'Id' } } },
    { label: 'Make', fieldName: 'Make__c' },
    { label: 'Location', fieldName: 'Location_Name__c' },
    { label: 'Year', fieldName: 'Year__c' },
    { label: 'Mileage', fieldName: 'Mileage__c', type: 'number' },
    { label: 'Days on Lot', fieldName: 'DaysOnLot', type: 'number' },
    { label: 'Value', fieldName: 'Value__c', type: 'currency' },
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
            (r.Location_Name__c && r.Location_Name__c.toLowerCase().includes(this.searchTerm)) ||
            this._matchesState(r.Location_State__c, this.searchTerm) ||
            (r.Color__c && r.Color__c.toLowerCase().includes(this.searchTerm))
        );
    }

    _matchesState(stateValue, term) {
        if (!stateValue || !term) return false;

        const value = stateValue.toLowerCase();
        if (value.includes(term)) {
            return true;
        }

        const fullStateName = STATE_NAME_BY_CODE[stateValue.toUpperCase()];
        return fullStateName ? fullStateName.includes(term) : false;
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
        const locationName = record.Location__r && record.Location__r.Name
            ? record.Location__r.Name
            : 'Unknown';

        return {
            ...record,
            IdUrl: record.Id ? '/' + record.Id : undefined,
            DaysOnLot: record.Number_of_Days_on_Lot__c,
            Location_Name__c: locationName,
            Location_State__c: record.Location__r ? record.Location__r.State__c : undefined,
            RecordTypeName: record.RecordType ? record.RecordType.DeveloperName : undefined
        };
    }
}
