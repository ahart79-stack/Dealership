import { LightningElement } from 'lwc';
import getMyCarsAndPurchases from '@salesforce/apex/MyCarsAndPurchasesController.getMyCarsAndPurchases';
import getServicePicklistData from '@salesforce/apex/MyCarsAndPurchasesController.getServicePicklistData';
import submitDetailedServiceRequest from '@salesforce/apex/MyCarsAndPurchasesController.submitDetailedServiceRequest';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const ALL_DAY_TIME_VALUE = 'ALL_DAY';
const TIME_SLOT_OPTIONS = buildTimeSlotOptions();

const AUTOMOBILE_COLUMNS = [
	{ label: 'Vehicle', fieldName: 'name' },
	{ label: 'Make', fieldName: 'make' },
	{ label: 'Year', fieldName: 'year' },
	{ label: 'Mileage', fieldName: 'mileage', type: 'number' },
	{ label: 'Sale Price', fieldName: 'salesPrice', type: 'currency' }
];

const PURCHASE_COLUMNS = [
	{ label: 'Purchased', fieldName: 'purchasedDate', type: 'date' },
	{ label: 'Vehicle', fieldName: 'automobileName' },
	{ label: 'Make', fieldName: 'make' },
	{ label: 'Year', fieldName: 'year' },
	{ label: 'Purchase Price', fieldName: 'purchasePrice', type: 'currency' }
];

const OPEN_CASE_COLUMNS = [
	{ label: 'Case #', fieldName: 'caseNumber' },
	{ label: 'Subject', fieldName: 'subject' },
	{ label: 'Status', fieldName: 'status' },
	{ label: 'Opened', fieldName: 'openedDate', type: 'date' }
];

export default class MyCarsAndPurchases extends LightningElement {
	automobileColumns = AUTOMOBILE_COLUMNS;
	purchaseColumns = PURCHASE_COLUMNS;
	openCaseColumns = OPEN_CASE_COLUMNS;
	dashboard;
	errorMessage;
	loading = false;
	activeTabValue = 'cars';
	serviceStep = 'select';
	selectedServiceCarId;
	serviceConcernSummary = '';
	serviceType = '';
	serviceSubType = '';
	serviceMileage;
	serviceTypeOptions = [];
	serviceSubTypeOptions = [];
	preferredDateOptions = [];
	timeSlotOptions = TIME_SLOT_OPTIONS;
	servicePreferredDate = '';
	serviceTime = '';
	serviceContactPhone = '';
	serviceAdditionalDetails = '';
	isSubmittingServiceRequest = false;

	connectedCallback() {
		this.loadDashboard();
		this.loadServicePicklists();
		this.preferredDateOptions = this.buildPreferredDateOptions();
	}

	get contactName() {
		return this.dashboard?.contactName || 'Your Account';
	}

	get automobileRows() {
		return this.dashboard?.automobiles || [];
	}

	get purchaseRows() {
		return this.dashboard?.purchases || [];
	}

	get hasContact() {
		return this.dashboard?.hasContact;
	}

	get hasAutomobiles() {
		return this.automobileRows.length > 0;
	}

	get hasPurchases() {
		return this.purchaseRows.length > 0;
	}

	get automobileCount() {
		return this.dashboard?.automobileCount || 0;
	}

	get purchaseCount() {
		return this.dashboard?.purchaseCount || 0;
	}

	get totalSpent() {
		return this.dashboard?.totalSpent || 0;
	}

	get defaultContactPhone() {
		return this.dashboard?.contactPhone || '';
	}

	get carsTabLabel() {
		return `Cars (${this.automobileCount})`;
	}

	get purchasesTabLabel() {
		return `Purchases (${this.purchaseCount})`;
	}

	get openCaseRows() {
		return this.dashboard?.openCases || [];
	}

	get hasOpenCases() {
		return this.openCaseRows.length > 0;
	}

	get openCaseCount() {
		return this.dashboard?.openCaseCount || 0;
	}

	get openCasesTabLabel() {
		return `Open Service Items (${this.openCaseCount})`;
	}

	get isServiceTabActive() {
		return this.activeTabValue === 'service';
	}

	get isServiceSelectStep() {
		return this.serviceStep === 'select';
	}

	get isServiceDetailsStep() {
		return this.serviceStep === 'details';
	}

	get selectedServiceCarIds() {
		return this.selectedServiceCarId ? [this.selectedServiceCarId] : [];
	}

	get selectedServiceCar() {
		return this.automobileRows.find((row) => row.automobileId === this.selectedServiceCarId);
	}

	get hasSelectedServiceCar() {
		return Boolean(this.selectedServiceCar);
	}

	get disableContinueToServiceDetails() {
		return !this.hasSelectedServiceCar;
	}

	get disableSubmitServiceRequest() {
		return (
			!this.hasSelectedServiceCar ||
			this.serviceMileage === null ||
			this.serviceMileage === undefined ||
			!this.servicePreferredDate ||
			!this.serviceTime ||
			this.isSubmittingServiceRequest
		);
	}

	handleRequestService() {
		this.activeTabValue = 'service';
	}

	handleCancelServiceRequest() {
		this.activeTabValue = 'cars';
		this.resetServiceState();
	}

	handleTabActivated(event) {
		this.activeTabValue = event.target.value;
	}

	handleServiceCarSelection(event) {
		const selectedRows = event.detail.selectedRows || [];
		this.selectedServiceCarId = selectedRows.length > 0 ? selectedRows[0].automobileId : undefined;
	}

	handleContinueToServiceDetails() {
		if (!this.hasSelectedServiceCar) {
			return;
		}

		this.serviceStep = 'details';
	}

	handleBackToServiceSelection() {
		this.serviceStep = 'select';
	}

	handleServiceInputChange(event) {
		const fieldName = event.target?.dataset?.field;
		const value = event.target?.value || '';

		if (fieldName === 'concernSummary') {
			this.serviceConcernSummary = value;
		} else if (fieldName === 'serviceType') {
			this.serviceType = value;
		} else if (fieldName === 'serviceSubType') {
			this.serviceSubType = value;
		} else if (fieldName === 'serviceMileage') {
			this.serviceMileage = value === '' ? undefined : Number(value);
		} else if (fieldName === 'preferredDate') {
			this.servicePreferredDate = value;
		} else if (fieldName === 'serviceTime') {
			this.serviceTime = value;
		} else if (fieldName === 'contactPhone') {
			this.serviceContactPhone = value;
		} else if (fieldName === 'additionalDetails') {
			this.serviceAdditionalDetails = value;
		}
	}

	handleSubmitServiceRequest() {
		if (!this.selectedServiceCarId || this.isSubmittingServiceRequest) {
			return;
		}

		this.isSubmittingServiceRequest = true;
		submitDetailedServiceRequest({
			automobileId: this.selectedServiceCarId,
			concernSummary: this.serviceConcernSummary?.trim() || null,
			serviceType: this.serviceType?.trim() || null,
			serviceSubType: this.serviceSubType?.trim() || null,
			serviceMileage: this.serviceMileage,
			preferredServiceDate: this.servicePreferredDate || null,
				serviceTime: this.serviceTime || null,
			contactPhone: this.serviceContactPhone?.trim() || null,
			additionalDetails: this.serviceAdditionalDetails?.trim() || null
		})
			.then((result) => {
				const caseNumber = result?.caseNumber ? ` ${result.caseNumber}` : '';
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Service request submitted',
						message: `Case${caseNumber} was created for ${this.selectedServiceCar?.name || 'your car'}.`,
						variant: 'success'
					})
				);
				this.handleCancelServiceRequest();
				this.loadDashboard();
			})
			.catch((error) => {
				const message = error?.body?.message || error?.message || 'Unable to submit your service request.';
				this.dispatchEvent(
					new ShowToastEvent({
						title: 'Service request failed',
						message,
						variant: 'error'
					})
				);
			})
			.finally(() => {
				this.isSubmittingServiceRequest = false;
			});
	}

	handleRefresh() {
		this.loadDashboard();
	}

	loadDashboard() {
		this.loading = true;
		getMyCarsAndPurchases()
			.then((data) => {
				this.dashboard = data;
				this.errorMessage = undefined;
				if (!this.serviceContactPhone) {
					this.serviceContactPhone = this.defaultContactPhone;
				}
				if (!this.automobileRows.some((row) => row.automobileId === this.selectedServiceCarId)) {
					this.selectedServiceCarId = undefined;
				}
			})
			.catch((error) => {
				this.dashboard = undefined;
				this.errorMessage = error?.body?.message || error?.message || 'Unable to load your cars and purchases.';
			})
			.finally(() => {
				this.loading = false;
			});
	}

	loadServicePicklists() {
		getServicePicklistData()
			.then((data) => {
				this.serviceTypeOptions = data?.typeOptions || [];
				this.serviceSubTypeOptions = data?.subTypeOptions || [];
			})
			.catch(() => {
				this.serviceTypeOptions = [];
				this.serviceSubTypeOptions = [];
			});
	}

	resetServiceState() {
		this.serviceStep = 'select';
		this.selectedServiceCarId = undefined;
		this.serviceConcernSummary = '';
		this.serviceType = '';
		this.serviceSubType = '';
		this.serviceMileage = undefined;
		this.servicePreferredDate = '';
		this.serviceTime = '';
		this.serviceContactPhone = this.defaultContactPhone;
		this.serviceAdditionalDetails = '';
	}

	buildPreferredDateOptions() {
		const options = [];
		const baseDate = new Date();
		for (let i = 0; i < 60; i += 1) {
			const optionDate = new Date(baseDate);
			optionDate.setDate(baseDate.getDate() + i);
			if (optionDate.getDay() === 0) {
				continue;
			}

			const isoDate = optionDate.toISOString().slice(0, 10);
			const label = optionDate.toLocaleDateString(undefined, {
				weekday: 'short',
				year: 'numeric',
				month: 'short',
				day: 'numeric'
			});
			options.push({ label, value: isoDate });
		}
		return options;
	}
}

function buildTimeSlotOptions() {
	const options = [{ label: 'All Day', value: ALL_DAY_TIME_VALUE }];
	for (let minutes = 8 * 60; minutes <= 17 * 60; minutes += 30) {
		const hour = Math.floor(minutes / 60);
		const minute = minutes % 60;
		const normalizedHour = hour % 12 || 12;
		const suffix = hour >= 12 ? 'PM' : 'AM';
		const minuteLabel = minute === 0 ? '00' : String(minute);
		const hourValue = String(hour).padStart(2, '0');
		const minuteValue = String(minute).padStart(2, '0');
		options.push({
			label: `${normalizedHour}:${minuteLabel} ${suffix}`,
			value: `${hourValue}:${minuteValue}`
		});
	}
	return options;
}