Set<String> targetPrefixes = new Set<String>{'SLA', 'SCA'};
Set<String> seen = new Set<String>();

for (Integer page = 1; page <= 20; page++) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://api.auto.dev/listings?page=' + page + '&limit=200&sort=year.desc&retailListing.state=PA');
    req.setMethod('GET');
    req.setHeader('Accept', 'application/json');
    req.setHeader('Authorization', 'Bearer ' + System.Label.AutoDevApiKey);
    req.setTimeout(120000);

    HttpResponse res = new Http().send(req);
    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
        System.debug('AUTO_DEV_PAGE_FAIL page=' + page + ' status=' + res.getStatusCode());
        continue;
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    List<Object> data = payload == null ? new List<Object>() : (List<Object>) payload.get('data');

    for (Object row : data) {
        Map<String, Object> listing = (Map<String, Object>) row;
        Map<String, Object> vehicle = listing.containsKey('vehicle') && listing.get('vehicle') != null
            ? (Map<String, Object>) listing.get('vehicle')
            : new Map<String, Object>();

        String vin = (String) (listing.get('vin') == null ? vehicle.get('vin') : listing.get('vin'));
        String make = (String) vehicle.get('make');

        if (String.isBlank(vin) || vin.length() < 3) {
            continue;
        }

        String prefix = vin.substring(0, 3);
        if (targetPrefixes.contains(prefix)) {
            String key = vin + '|' + make;
            if (!seen.contains(key)) {
                seen.add(key);
                System.debug('AUTO_DEV_VIN_MAKE page=' + page + ' vin=' + vin + ' make=' + make);
            }
        }
    }
}

System.debug('AUTO_DEV_VIN_MAKE_TOTAL=' + seen.size());
