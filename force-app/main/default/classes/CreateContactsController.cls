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
            String[] firstNames = new String[]{
                'Alex','Sam','Taylor','Jordan','Casey','Jamie','Chris','Pat','Lee','Morgan',
                'Dana','Robin','Quinn','Blake','Skyler','Avery','Cameron','Drew','Reese','Logan',
                'Peyton','Sydney','Hayden','Jesse','Alexis','Bailey','Dylan','Emerson','Finley','Harper',
                'Hunter','Kendall','Lane','Marley','Parker','Remy','River','Rowan','Sage','Spencer',
                'Sutton','Tatum','Teagan','Wren','Zion','Arlo','Beau','Brody','Caleb','Cole',
                'Connor','Declan','Eli','Ethan','Felix','Gavin','Henry','Ian','Jack','Jake',
                'James','Jonah','Julian','Kai','Landon','Liam','Lucas','Mason','Miles','Nathan',
                'Noah','Nolan','Owen','Ryan','Sean','Seth','Tristan','Tyler','Victor','Wyatt',
                'Abby','Amber','Amy','Anna','Aria','Audrey','Bella','Brooke','Claire','Chloe',
                'Elena','Eva','Grace','Hannah','Isla','Ivy','Jane','Julia','Kate','Laura'
            };
            String[] lastNames = new String[]{
                'Smith','Johnson','Brown','Taylor','Anderson','Thomas','Jackson','White','Harris','Martin',
                'Thompson','Garcia','Martinez','Robinson','Clark','Rodriguez','Lewis','Lee','Walker','Hall',
                'Allen','Young','Hernandez','King','Wright','Lopez','Hill','Scott','Green','Adams',
                'Baker','Gonzalez','Nelson','Carter','Mitchell','Perez','Roberts','Turner','Phillips','Campbell',
                'Parker','Evans','Edwards','Collins','Stewart','Sanchez','Morris','Rogers','Reed','Cook',
                'Morgan','Bell','Murphy','Bailey','Rivera','Cooper','Richardson','Cox','Howard','Ward',
                'Torres','Peterson','Gray','Ramirez','James','Watson','Brooks','Kelly','Sanders','Price',
                'Bennett','Wood','Barnes','Ross','Henderson','Coleman','Jenkins','Perry','Powell','Long',
                'Patterson','Hughes','Flores','Washington','Butler','Simmons','Foster','Gonzales','Bryant','Alexander',
                'Hart','Chapman','Ripley','Grey','Ogawa','Field','Reuss','Barra','Green','James'
            };
            String[] areaCodes = new String[]{'415','212','303','720','312','206','503','215','404','313',
                                              '617','512','702','602','305','443','614','901','907','808'};
            
            for (Integer i = 0; i < count; i++){
                Integer fnIdx = Math.mod(Math.abs(Crypto.getRandomInteger()), firstNames.size());
                Integer lnIdx = Math.mod(Math.abs(Crypto.getRandomInteger()), lastNames.size());
                String fn = firstNames[fnIdx];
                String ln = lastNames[lnIdx];
                Integer suffix = 1000 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9000);
                String email = (fn + '.' + ln + suffix + '@testdata.example.com').toLowerCase();
                
                Integer acIdx = Math.mod(Math.abs(Crypto.getRandomInteger()), areaCodes.size());
                String areaCode = areaCodes[acIdx];
                Integer prefix = 200 + Math.mod(Math.abs(Crypto.getRandomInteger()), 600);
                Integer line = 1000 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9000);
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
