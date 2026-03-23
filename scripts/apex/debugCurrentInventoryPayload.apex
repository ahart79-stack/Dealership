List<Automobile__c> rows = CurrentInventoryController.getInventory(5);
System.debug(JSON.serializePretty(rows));
