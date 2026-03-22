public with sharing class CreateContactsController {
    @AuraEnabled
    public static Integer createRandomContacts(Integer count) {
        try {
            if (count == null || count <= 0) count = 25;
            
            // Find or create Account with name 'Testdata'
            List<Account> existingAccounts = [SELECT Id FROM Account WHERE Name = 'Testdata' LIMIT 1];
            Id accountId;
            if (existingAccounts.isEmpty()) {
                Account newAccount = new Account(Name = 'Testdata');
                insert newAccount;
                accountId = newAccount.Id;
            } else {
                accountId = existingAccounts[0].Id;
            }

            List<Contact> contacts = new List<Contact>();
            String[] firstNames = new String[]{'Alex','Sam','Taylor','Jordan','Casey','Jamie','Chris','Pat','Lee','Morgan'};
            String[] lastNames = new String[]{'Smith','Johnson','Brown','Taylor','Anderson','Thomas','Jackson','White','Harris','Martin'};
            String[] areaCodes = new String[]{'415','212','303','720','312','206','503','215','404','313'};
            
            Long timestamp = System.currentTimeMillis();

            for (Integer i = 0; i < count; i++){
                String fn = firstNames[Math.mod(i, firstNames.size())];
                String ln = lastNames[Math.mod(i, lastNames.size())];
                String email = (fn + '.' + ln + timestamp + i + '@testdata.example.com').toLowerCase();
                
                String areaCode = areaCodes[Math.mod(i, areaCodes.size())];
                Integer prefix = 200 + Math.mod(i, 600);
                Integer line = 1000 + Math.mod(i, 9000);
                String phone = '(' + areaCode + ') ' + prefix + '-' + line;
                
                Contact c = new Contact(
                    FirstName = fn,
                    LastName = ln,
                    Email = email,
                    Phone = phone,
                    AccountId = accountId
                );
                contacts.add(c);
            }

            Integer created = 0;
            Database.SaveResult[] results = Database.insert(contacts, false);
            for (Database.SaveResult r : results) {
                if (r.isSuccess()) {
                    created++;
                }
            }
            return created;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
}
