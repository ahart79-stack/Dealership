import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDiscountEligibleAutos from '@salesforce/apex/AutomobileSales30_90Controller.getDiscountEligibleAutos';
import applyDiscounts from '@salesforce/apex/AutomobileSales30_90Controller.applyDiscounts';

const COLUMNS = [
    { label: 'Name',             fieldName: 'name',            type: 'text' },
    { label: 'Make',             fieldName: 'make',            type: 'text' },
    { label: 'Dealership',       fieldName: 'dealershipName',  type: 'text' },
    { label: 'Bought Date',      fieldName: 'boughtDate',      type: 'date' },
    { label: 'Days on Field',    fieldName: 'daysOnField',     type: 'number' },
    { label: 'Current Value',   fieldName: 'currentValue',    type: 'currency' },
    { label: 'Discount Amount', fieldName: 'discountedValue', type: 'currency' }
];

export default class AutomobileSales30_90 extends LightningElement {
    @track isApplying = false;
    @track successMessage = '';
    @track error = '';
    wiredResult;
    columns = COLUMNS;

    @wire(getDiscountEligibleAutos)
    wiredAutos(result) {
        this.wiredResult = result;
        if (result.error) {
            this.error = result.error.body?.message || JSON.stringify(result.error);
        }
    }

    get allAutos() {
        return (this.wiredResult && this.wiredResult.data) ? this.wiredResult.data : [];
    }

    get autos3060() {
        return this.allAutos.filter(a => a.tier === '30_60');
    }

    get autos60plus() {
        return this.allAutos.filter(a => a.tier === '60_plus');
    }

    get count3060() {
        return this.autos3060.length;
    }

    get count60plus() {
        return this.autos60plus.length;
    }

    get has3060Autos() {
        return this.autos3060.length > 0;
    }

    get has60plusAutos() {
        return this.autos60plus.length > 0;
    }

    get hasError() {
        return !!this.error;
    }

    handleApplyDiscounts() {
        this.isApplying = true;
        this.successMessage = '';
        this.error = '';

        applyDiscounts()
            .then(count => {
                this.successMessage = `Discounts applied to ${count} vehicle(s).`;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: `Discounts applied to ${count} vehicle(s).`,
                    variant: 'success'
                }));
                return refreshApex(this.wiredResult);
            })
            .catch(err => {
                this.error = err.body?.message || JSON.stringify(err);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error applying discounts',
                    message: this.error,
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isApplying = false;
            });
    }
}