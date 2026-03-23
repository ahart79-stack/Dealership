// Fix the 2 contacts with names that produce invalid email addresses
Map<Id, String> fixedEmails = new Map<Id, String>{
    '003g500000AyLfiAAF' => 'jeremie.papin' + (1000 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9000)) + '@testdata.example.com',
    '003g500000AyLfnAAF' => 'seung.jolee'  + (1000 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9000)) + '@testdata.example.com'
};

List<Contact> updates = new List<Contact>();
for (Id cId : fixedEmails.keySet()) {
    updates.add(new Contact(Id = cId, Email = fixedEmails.get(cId)));
}

Database.SaveResult[] results = Database.update(updates, false);
for (Database.SaveResult r : results) {
    if (r.isSuccess()) {
        System.debug('Fixed: ' + r.getId());
    } else {
        for (Database.Error e : r.getErrors()) {
            System.debug('Error: ' + e.getMessage());
        }
    }
}
