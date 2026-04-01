import { createElement } from '@lwc/engine-dom';
import TopCustomers from 'c/topCustomers';
import getTopCustomers from '@salesforce/apex/TopCustomersController.getTopCustomers';

jest.mock(
    '@salesforce/apex/TopCustomersController.getTopCustomers',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

const flushPromises = () => Promise.resolve();

describe('c-top-customers', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }

        jest.clearAllMocks();
    });

    it('renders a datatable of top customers', async () => {
        getTopCustomers.mockResolvedValue([
            {
                contactId: '003xx0000000001',
                contactName: 'Alex Buyer',
                email: 'alex@example.com',
                phone: '555-1000',
                purchaseCount: 4,
                totalSpent: 98000,
                lastPurchaseDate: '2026-03-20'
            }
        ]);

        const element = createElement('c-top-customers', {
            is: TopCustomers
        });
        document.body.appendChild(element);

        await flushPromises();
        await flushPromises();

        const card = element.shadowRoot.querySelector('lightning-card');
        const table = element.shadowRoot.querySelector('lightning-datatable');

        expect(card.title).toBe('Top Customers');
        expect(table.data).toEqual([
            {
                contactId: '003xx0000000001',
                contactNameUrl: '/003xx0000000001',
                contactName: 'Alex Buyer',
                email: 'alex@example.com',
                phone: '555-1000',
                purchaseCount: 4,
                totalSpent: 98000,
                lastPurchaseDate: '2026-03-20'
            }
        ]);
        expect(getTopCustomers).toHaveBeenCalledWith({ limitSize: 10 });
    });

    it('renders an empty state when there is no data', async () => {
        getTopCustomers.mockResolvedValue([]);

        const element = createElement('c-top-customers', {
            is: TopCustomers
        });
        document.body.appendChild(element);

        await flushPromises();
        await flushPromises();

        expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
        expect(element.shadowRoot.textContent).toContain('No customer purchases found.');
    });
});