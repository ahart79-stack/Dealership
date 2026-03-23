// Backfill clean email addresses on all contacts
// Format: firstname.lastname1042@testdata.example.com

List<Contact> contacts = [SELECT Id, FirstName, LastName, Email FROM Contact];
List<Contact> updates = new List<Contact>();

for (Contact c : contacts) {
    String fn = c.FirstName == null ? 'unknown' : c.FirstName.toLowerCase();
    String ln = c.LastName == null ? 'unknown' : c.LastName.toLowerCase();

    // Check if email is blank or still has the ugly long timestamp format.
    // Timestamp emails contain 7+ consecutive digits (13-digit epoch) before the @.
    Boolean hasTimestamp = false;
    if (!String.isBlank(c.Email)) {
        String localPart = c.Email.substringBefore('@');
        Integer consec = 0;
        for (Integer j = 0; j < localPart.length(); j++) {
            String ch = localPart.substring(j, j + 1);
            if (ch >= '0' && ch <= '9') {
                consec++;
                if (consec >= 7) { hasTimestamp = true; break; }
            } else {
                consec = 0;
            }
        }
    }
    Boolean needsEmail = String.isBlank(c.Email) || hasTimestamp;
    if (needsEmail) {
        Integer suffix = 1000 + Math.mod(Math.abs(Crypto.getRandomInteger()), 9000);
        c.Email = fn + '.' + ln + suffix + '@testdata.example.com';
        updates.add(c);
    }
}

Integer successCount = 0;
Integer failureCount = 0;
if (!updates.isEmpty()) {
    Database.SaveResult[] results = Database.update(updates, false);
    for (Database.SaveResult r : results) {
        if (r.isSuccess()) { successCount++; } else {
            failureCount++;
            for (Database.Error e : r.getErrors()) {
                System.debug('Email backfill error: ' + e.getMessage());
            }
        }
    }
}
System.debug('Email backfill complete. Updated: ' + successCount + ', Failed: ' + failureCount);
