HttpRequest req = new HttpRequest();
req.setEndpoint('https://api.auto.dev/listings?page=1&limit=200&sort=year.desc&retailListing.state=PA');
req.setMethod('GET');
req.setHeader('Accept', 'application/json');
req.setHeader('Authorization', 'Bearer ' + System.Label.AutoDevApiKey);
req.setTimeout(120000);

HttpResponse res = new Http().send(req);
System.debug('AUTO_DEV_INSPECT status=' + res.getStatusCode());

Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
List<Object> data = payload == null ? new List<Object>() : (List<Object>) payload.get('data');

for (Object row : data) {
    Map<String, Object> listing = (Map<String, Object>) row;
    Map<String, Object> vehicle = listing.containsKey('vehicle') && listing.get('vehicle') != null
        ? (Map<String, Object>) listing.get('vehicle')
        : new Map<String, Object>();

    String vin = (String) (listing.get('vin') == null ? vehicle.get('vin') : listing.get('vin'));
    String make = (String) vehicle.get('make');

    if (vin != null && (vin.startsWith('SLA') || vin.startsWith('SCA'))) {
        System.debug('AUTO_DEV_VIN_MAKE vin=' + vin + ' make=' + make);
    }
}
