import { createElement } from '@lwc/engine-dom';
import InventoryatLocation from 'c/inventoryatLocation';
import getVehicleCountByLocation from '@salesforce/apex/InventoryAtLocationController.getVehicleCountByLocation';
import getContactsWithMoreThanTwoPurchases from '@salesforce/apex/InventoryAtLocationController.getContactsWithMoreThanTwoPurchases';

jest.mock(
    '@salesforce/apex/InventoryAtLocationController.getVehicleCountByLocation',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/InventoryAtLocationController.getContactsWithMoreThanTwoPurchases',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

const flushPromises = () => Promise.resolve();

describe('c-inventoryat-location', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }

        jest.clearAllMocks();
    });

    it('renders location and repeat-buyer tables', async () => {
        getVehicleCountByLocation.mockResolvedValue([
            { locationId: 'a01', locationName: 'Austin', vehicleCount: 12 }
        ]);
        getContactsWithMoreThanTwoPurchases.mockResolvedValue([
            {
                contactId: '003',
                contactName: 'Alex Buyer',
                email: 'alex@example.com',
                phone: '555-1000',
                purchaseCount: 3
            }
        ]);

        const element = createElement('c-inventoryat-location', {
            is: InventoryatLocation
        });
        document.body.appendChild(element);

        await flushPromises();
        await flushPromises();

        const tables = element.shadowRoot.querySelectorAll('lightning-datatable');
        expect(tables).toHaveLength(2);
        expect(tables[0].data).toEqual([
            { locationId: 'a01', locationName: 'Austin', vehicleCount: 12 }
        ]);
        expect(tables[1].data).toEqual([
            {
                contactId: '003',
                contactName: 'Alex Buyer',
                email: 'alex@example.com',
                phone: '555-1000',
                purchaseCount: 3
            }
        ]);
        expect(getVehicleCountByLocation).toHaveBeenCalledTimes(1);
        expect(getContactsWithMoreThanTwoPurchases).toHaveBeenCalledTimes(1);
    });
});