List<String> vins = new List<String>{
    'SLA23HA01VU236340',
    'SLA23HA08VU236299',
    'SCA23GZ01VU236370'
};

for (String targetVin : vins) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://api.auto.dev/listings?limit=50&sort=year.desc&retailListing.state=PA&vin=' + EncodingUtil.urlEncode(targetVin, 'UTF-8'));
    req.setMethod('GET');
    req.setHeader('Accept', 'application/json');
    req.setHeader('Authorization', 'Bearer ' + System.Label.AutoDevApiKey);
    req.setTimeout(120000);

    HttpResponse res = new Http().send(req);
    System.debug('AUTO_DEV_LOOKUP status=' + res.getStatusCode() + ' vin=' + targetVin);

    if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
        continue;
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    List<Object> data = payload == null ? new List<Object>() : (List<Object>) payload.get('data');

    String foundMake;
    for (Object row : data) {
        Map<String, Object> listing = (Map<String, Object>) row;
        Map<String, Object> vehicle = listing.containsKey('vehicle') && listing.get('vehicle') != null
            ? (Map<String, Object>) listing.get('vehicle')
            : new Map<String, Object>();

        String vin = (String) (listing.get('vin') == null ? vehicle.get('vin') : listing.get('vin'));
        if (vin == targetVin) {
            foundMake = (String) vehicle.get('make');
            break;
        }
    }

    System.debug('AUTO_DEV_LOOKUP_RESULT vin=' + targetVin + ' make=' + foundMake + ' rows=' + data.size());
}
