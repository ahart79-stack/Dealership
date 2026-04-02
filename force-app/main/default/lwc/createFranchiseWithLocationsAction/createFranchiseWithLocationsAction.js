import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getLocations from '@salesforce/apex/CreateFranchiseActionController.getLocations';
import getFranchises from '@salesforce/apex/CreateFranchiseActionController.getFranchises';
import upsertFranchise from '@salesforce/apex/CreateFranchiseActionController.upsertFranchise';

export default class CreateFranchiseWithLocationsAction extends LightningElement {
    @api recordId;

    @track locationOptions = [];
    @track franchiseOptions = [];
    @track selectedLocationIds = [];

    actionMode = 'create';
    selectedFranchiseId = null;
    franchiseName = '';
    isSaving = false;

    modeOptions = [
        { label: 'Create New Franchise', value: 'create' },
        { label: 'Update Existing Franchise', value: 'update' }
    ];

    connectedCallback() {
        this.loadLocations();
        this.loadFranchises();
        if (this.recordId) {
            this.selectedLocationIds = [this.recordId];
        }
    }

    async loadLocations() {
        try {
            const options = await getLocations();
            this.locationOptions = options || [];
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    async loadFranchises() {
        try {
            const options = await getFranchises();
            this.franchiseOptions = options || [];
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        }
    }

    handleModeChange(event) {
        this.actionMode = event.detail.value;
        if (this.actionMode === 'create') {
            this.selectedFranchiseId = null;
        }
    }

    handleFranchiseSelectChange(event) {
        this.selectedFranchiseId = event.detail.value;
    }

    handleNameChange(event) {
        this.franchiseName = event.target.value;
    }

    handleLocationsChange(event) {
        this.selectedLocationIds = event.detail.value;
    }

    async handleSave() {
        if (this.isCreateMode && (!this.franchiseName || !this.franchiseName.trim())) {
            this.showToast('Validation', 'Franchise Name is required.', 'warning');
            return;
        }

        if (!this.isCreateMode && !this.selectedFranchiseId) {
            this.showToast('Validation', 'Select an existing Franchise to update.', 'warning');
            return;
        }

        this.isSaving = true;
        try {
            await upsertFranchise({
                mode: this.actionMode,
                franchiseId: this.selectedFranchiseId,
                franchiseName: this.franchiseName,
                locationIds: this.selectedLocationIds
            });

            this.showToast('Success', this.successMessage, 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    getErrorMessage(error) {
        const body = error?.body;
        if (Array.isArray(body)) {
            const messages = body.map((entry) => entry?.message).filter(Boolean);
            if (messages.length) {
                return messages.join('; ');
            }
        }

        if (body?.message) {
            return body.message;
        }

        if (body?.pageErrors?.length) {
            return body.pageErrors.map((entry) => entry.message).join('; ');
        }

        if (body?.fieldErrors) {
            const fieldMessages = [];
            Object.keys(body.fieldErrors).forEach((fieldName) => {
                (body.fieldErrors[fieldName] || []).forEach((entry) => {
                    if (entry?.message) {
                        fieldMessages.push(entry.message);
                    }
                });
            });
            if (fieldMessages.length) {
                return fieldMessages.join('; ');
            }
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    get isCreateMode() {
        return this.actionMode === 'create';
    }

    get panelHeader() {
        return this.isCreateMode ? 'New Franchise' : 'Update Franchise';
    }

    get saveLabel() {
        return this.isCreateMode ? 'Create Franchise' : 'Update Franchise';
    }

    get successMessage() {
        return this.isCreateMode
            ? 'Franchise created and locations related.'
            : 'Franchise updated and locations related.';
    }
}
