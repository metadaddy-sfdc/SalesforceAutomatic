public class AutomaticUtils {
    private static AutomaticAPI__c settings = AutomaticAPI__c.getInstance();
    private static String authProviderId   = settings.authProviderId__c;
    private static String authProviderName = settings.authProviderName__c;
    private static String authProviderType = settings.authProviderType__c;

    static String baseUrl = 'https://api.automatic.com/v1';
    
    public static String getResource(String accessToken, String path) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl+path);
        req.setMethod('GET');
        req.setTimeout(60*1000);
        req.setHeader('Authorization', 'token '+accessToken);
    
        Http h = new Http();
        HttpResponse res = h.send(req);
        
        System.debug('getResource - HTTP: '+res);
        
        String resp = res.getBody();
        Integer statusCode = res.getStatusCode();
        if (statusCode == 401 || statusCode == 403) {
            System.debug('Refreshing access token');
            Map<String, String> refreshMap = Auth.AuthToken.refreshAccessToken(authProviderId, 
                                              authProviderName, 
                                              accessToken);
            System.debug(refreshMap);
            accessToken = refreshMap.get('AccessToken');
            if (accessToken != null) {
	            return getResource(accessToken, path);
            } else {
                throw new AutomaticException('Error getting access token: '+refreshMap.get('RefreshError'));
            }
        }
        
        System.debug('getResource - JSON: '+resp);

		return resp;        
    }    
    
    public static Vehicle__c makeVehicle(Map<String, Object> vehicle) {
        return new Vehicle__c(
            Automatic_Id__c = (String)vehicle.get('id'),
            Name = (String)vehicle.get('display_name'),
            Year__c = String.valueOf((Integer)vehicle.get('year')),
            Make__c = (String)vehicle.get('make'),
            Model__c = (String)vehicle.get('model'),
            Color__c = (String)vehicle.get('color')
        );
    }
    
    public static Trip__c makeTrip(User u, Vehicle__c v, Map<String, Object> trip) {
    	Map<String, Object> startLocation = (Map<String, Object>)trip.get('start_location');
    	Map<String, Object> endLocation = (Map<String, Object>)trip.get('end_location');
        
    	return new Trip__c(
            Driver__c = u.id,
            uri__c = (String)trip.get('uri'),
            Automatic_Id__c = (String)trip.get('id'),
            Start_Time__c = Datetime.newInstance((Long)trip.get('start_time')),
            Start_Time_Zone__c = (String)trip.get('start_time_zone'),
            End_Time__c = Datetime.newInstance((Long)trip.get('end_time')),
            End_Time_Zone__c = (String)trip.get('end_time_zone'),
            Path__c = (String)trip.get('path'),
            Vehicle__c = v.id,
            MPG__c = (Double)trip.get('average_mpg'),
            Distance_Meters__c = (Double)trip.get('distance_m'),
            Start_Location_Name__c = (String)startLocation.get('name'),
            Start_Location__Latitude__s = (Double)startLocation.get('lat'),
            Start_Location__Longitude__s = (Double)startLocation.get('lon'),
            End_Location_Name__c = (String)endLocation.get('name'),
            End_Location__Latitude__s = (Double)endLocation.get('lat'),
            End_Location__Longitude__s = (Double)endLocation.get('lon') 
        );
    }
}