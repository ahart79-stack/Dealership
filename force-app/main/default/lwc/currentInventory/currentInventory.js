import { LightningElement, track, wire } from 'lwc';
import getInventory from '@salesforce/apex/CurrentInventoryController.getInventory';
import { refreshApex } from '@salesforce/apex';

const STATE_NAME_BY_CODE = {
    AL: 'Alabama', AK: 'Alaska', AZ: 'Arizona', AR: 'Arkansas', CA: 'California',
    CO: 'Colorado', CT: 'Connecticut', DE: 'Delaware', FL: 'Florida', GA: 'Georgia',
    HI: 'Hawaii', ID: 'Idaho', IL: 'Illinois', IN: 'Indiana', IA: 'Iowa',
    KS: 'Kansas', KY: 'Kentucky', LA: 'Louisiana', ME: 'Maine', MD: 'Maryland',
    MA: 'Massachusetts', MI: 'Michigan', MN: 'Minnesota', MS: 'Mississippi', MO: 'Missouri',
    MT: 'Montana', NE: 'Nebraska', NV: 'Nevada', NH: 'New Hampshire', NJ: 'New Jersey',
    NM: 'New Mexico', NY: 'New York', NC: 'North Carolina', ND: 'North Dakota', OH: 'Ohio',
    OK: 'Oklahoma', OR: 'Oregon', PA: 'Pennsylvania', RI: 'Rhode Island', SC: 'South Carolina',
    SD: 'South Dakota', TN: 'Tennessee', TX: 'Texas', UT: 'Utah', VT: 'Vermont',
    VA: 'Virginia', WA: 'Washington', WV: 'West Virginia', WI: 'Wisconsin', WY: 'Wyoming'
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
    @track showLocationFilter = false;
    @track showStateFilter = false;
    @track showDistrictFilter = false;
    @track selectedLocation = '';
    @track selectedState = '';
    @track selectedDistrict = '';
    wiredInventoryResult;
    columns = COLUMNS;

    get locationOptions() {
        const countsByLocation = new Map();
        [...this.newAutos, ...this.usedAutos].forEach(row => {
            const name = row.Location_Name__c || 'Unknown';
            countsByLocation.set(name, (countsByLocation.get(name) || 0) + 1);
        });

        return Array.from(countsByLocation.entries())
            .sort((left, right) => left[0].localeCompare(right[0]))
            .map(([name, count]) => ({ label: `${name} (${count})`, value: name }));
    }

    get stateOptions() {
        const countsByState = new Map();
        [...this.newAutos, ...this.usedAutos].forEach(row => {
            const code = row.Location_State__c || 'Unknown';
            countsByState.set(code, (countsByState.get(code) || 0) + 1);
        });

        return Array.from(countsByState.entries())
            .sort((left, right) => left[0].localeCompare(right[0]))
            .map(([code, count]) => {
                const full = STATE_NAME_BY_CODE[code.toUpperCase()];
                const label = full ? `${code} - ${full} (${count})` : `${code} (${count})`;
                return { label, value: code };
            });
    }

    get districtOptions() {
        const countsByDistrict = new Map();
        [...this.newAutos, ...this.usedAutos].forEach(row => {
            const district = row.Location_District__c || 'Unknown';
            countsByDistrict.set(district, (countsByDistrict.get(district) || 0) + 1);
        });

        return Array.from(countsByDistrict.entries())
            .sort((left, right) => left[0].localeCompare(right[0]))
            .map(([district, count]) => ({ label: `${district} (${count})`, value: district }));
    }

    get newAutosFiltered() {
        return this._filterRows(this.newAutos);
    }

    get usedAutosFiltered() {
        return this._filterRows(this.usedAutos);
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
    }

    handleToggleLocationFilter() {
        this.showLocationFilter = !this.showLocationFilter;
    }

    handleToggleStateFilter() {
        this.showStateFilter = !this.showStateFilter;
    }

    handleToggleDistrictFilter() {
        this.showDistrictFilter = !this.showDistrictFilter;
    }

    handleLocationChange(event) {
        this.selectedLocation = event.detail.value;
    }

    handleStateChange(event) {
        this.selectedState = event.detail.value;
    }

    handleDistrictChange(event) {
        this.selectedDistrict = event.detail.value;
    }

    handleClearLocationFilter() {
        this.selectedLocation = '';
    }

    handleClearStateFilter() {
        this.selectedState = '';
    }

    handleClearDistrictFilter() {
        this.selectedDistrict = '';
    }

    handleResetFilters() {
        this.searchTerm = '';
        this.selectedLocation = '';
        this.selectedState = '';
        this.selectedDistrict = '';
        this.showLocationFilter = false;
        this.showStateFilter = false;
        this.showDistrictFilter = false;
    }

    _filterRows(rows) {
        return rows.filter(r => {
            const matchesLocation = !this.selectedLocation || r.Location_Name__c === this.selectedLocation;
            const rowState = r.Location_State__c || 'Unknown';
            const matchesState = !this.selectedState || rowState === this.selectedState;
            const rowDistrict = r.Location_District__c || 'Unknown';
            const matchesDistrict = !this.selectedDistrict || rowDistrict === this.selectedDistrict;

            const matchesSearch = !this.searchTerm ||
                (r.Name && r.Name.toLowerCase().includes(this.searchTerm)) ||
                (r.Make__c && r.Make__c.toLowerCase().includes(this.searchTerm)) ||
                (r.Year__c && String(r.Year__c).includes(this.searchTerm)) ||
                (r.Location_Name__c && r.Location_Name__c.toLowerCase().includes(this.searchTerm)) ||
                this._matchesState(r.Location_State__c, this.searchTerm) ||
                (r.Location_District__c && r.Location_District__c.toLowerCase().includes(this.searchTerm)) ||
                (r.Color__c && r.Color__c.toLowerCase().includes(this.searchTerm));

            return matchesLocation && matchesState && matchesDistrict && matchesSearch;
        });
    }

    _matchesState(stateValue, term) {
        if (!stateValue || !term) return false;

        const value = stateValue.toLowerCase();
        if (value.includes(term)) {
            return true;
        }

        const fullStateName = STATE_NAME_BY_CODE[stateValue.toUpperCase()];
        return fullStateName ? fullStateName.toLowerCase().includes(term) : false;
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
            Location_District__c: record.Location__r ? record.Location__r.District__c : undefined,
            RecordTypeName: record.RecordType ? record.RecordType.DeveloperName : undefined
        };
    }
}
