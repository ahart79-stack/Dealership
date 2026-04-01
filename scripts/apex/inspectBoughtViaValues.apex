Schema.SObjectField boughtViaField = Schema.SObjectType.Automobile__c.fields.getMap().get('Bought_Via__c');
for (Schema.PicklistEntry pe : boughtViaField.getDescribe().getPicklistValues()) {
    System.debug('BOUGHT_VIA_VALUE value=' + pe.getValue() + ' active=' + pe.isActive() + ' default=' + pe.isDefaultValue());
}
