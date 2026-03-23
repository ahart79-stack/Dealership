String[] areaCodes = new String[]{'415','212','303','720','312','206','503','215','404','313',
                                  '617','512','702','602','305','443','614','901','907','808'};

List<Contact> contacts = [SELECT Id FROM Contact WHERE Phone = null AND Account.Name = 'Testdata'];
List<Contact> updates = new List<Contact>();
for (Contact c : contacts) {
    String areaCode = areaCodes[Math.mod(Math.abs(Crypto.getRandomInteger()), areaCodes.size())];
    Integer prefix  = 200 + Math.mod(Math.abs(Crypto.getRandomInteger()), 600);
    Integer line    = 1000 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9000);
    c.Phone = '(' + areaCode + ') ' + prefix + '-' + line;
    updates.add(c);
}

Integer success = 0; Integer failed = 0;
if (!updates.isEmpty()) {
    for (Database.SaveResult r : Database.update(updates, false)) {
        if (r.isSuccess()) { success++; } else {
            failed++;
            for (Database.Error e : r.getErrors()) { System.debug('Error: ' + e.getMessage()); }
        }
    }
}
System.debug('Phone backfill complete. Updated: ' + success + ', Failed: ' + failed);
