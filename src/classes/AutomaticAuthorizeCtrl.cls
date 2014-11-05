/***************************************
* AutomaticAuthorizeCtrl.cls
* Handle Automatic OAuth and Fetching Trips
***************************************/
public with sharing class AutomaticAuthorizeCtrl {
    private String accessToken {get; set;}
    
    private static AutomaticAPI__c settings = AutomaticAPI__c.getInstance();
    private static String authProviderId   = settings.authProviderId__c;
    private static String authProviderName = settings.authProviderName__c;
    private static String authProviderType = settings.authProviderType__c;
    
	public AutomaticAuthorizeCtrl() {
		accessToken = Auth.AuthToken.getAccessToken(authProviderId, authProviderType);
        System.debug('Access token: '+accessToken);
    }    

	// THis method, called from a bound command button on the page, will redirect the user to Automatic's OAuth page, prompting
	// a login to Automatic if necessary
	public PageReference doRedirect() {
        return new PageReference('/services/auth/oauth/'+UserInfo.getOrganizationId()+'/'+authProviderName+'?'+
                                'startURL='+EncodingUtil.urlEncode(ApexPages.currentPage().getUrl(), 'UTF-8'));
	}
    
    public Boolean getAccessTokenIsValid() {
        if (accessToken != null) {
            // We have a token - see if it works
            try {
	            AutomaticUtils.getResource(accessToken, '/user');
                return true;
            } catch (AutomaticException e) {
                return false;
            }
        }
        
        return false;
    }
    
    public PageReference updateTrips() {
        List<Object> tripResponse;
        try {
			tripResponse = (List<Object>)JSON.deserializeUntyped(AutomaticUtils.getResource(accessToken, '/trips'));
        } catch (AutomaticException e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
            
			return null;
        }
        
        // Pull the vehicles and users out of the trips
        Map<String, Map<String, Object>> vehicleMap = new Map<String, Map<String, Object>>();
        Map<String, Map<String, Object>> userMap = new Map<String, Map<String, Object>>();
        for (Object tripObj : tripResponse) {
            Map<String, Object> trip = (Map<String, Object>)tripObj;
            
	        Map<String, Object> vehicle = (Map<String, Object>)trip.get('vehicle');            
            vehicleMap.put((String)vehicle.get('id'), vehicle);

            Map<String, Object> autoUser = (Map<String, Object>)trip.get('user');
            userMap.put((String)autoUser.get('id'), autoUser);
        }
        
        // Find vehicles we already know about
    	List<Vehicle__c> vehicles = [select id, name, automatic_id__c, year__c, make__c, model__c, color__c 
             from Vehicle__c 
             where automatic_id__c in :vehicleMap.keySet()];
        // Remove the known ones from our map
        Map<String, Map<String, Object>> savedVehicleMap = vehicleMap.clone();
        for (Vehicle__c vehicle : vehicles) {
            vehicleMap.remove(vehicle.automatic_id__c);
        }
        // Insert the remainder
        List<Vehicle__c> newVehicles = new List<Vehicle__c>();
        for (Map<String, Object> newVehicle : vehicleMap.values()) {
            newVehicles.add(AutomaticUtils.makeVehicle(newVehicle));
        }
        insert newVehicles;
        // Repopulate our list
    	vehicles = [select id, name, automatic_id__c, year__c, make__c, model__c, color__c 
             from Vehicle__c 
             where automatic_id__c in :savedVehicleMap.keySet()];
        // Map vehicle ids to records
        Map<String, Vehicle__c> vehicleIdMap = new Map<String, Vehicle__c>();
        for (Vehicle__c vehicle : vehicles) {
            vehicleIdMap.put(vehicle.automatic_id__c, vehicle);
        }
        
        // Find users we know about
        List<User> users = [select id, Automatic_Id__c
                            from User
                            where Automatic_Id__c in :userMap.keySet()];
        // We're not going to create users - just map user ids to records
        Map<String, User> userIdMap = new Map<String, User>();
        for (User user : users) {
            userIdMap.put(user.automatic_id__c, user);
        }

        // Now build a list of trips and insert it
        List<Trip__c> trips = new List<Trip__c>();
        for (Object tripObj : tripResponse) {
            Map<String, Object> trip = (Map<String, Object>)tripObj;
            
            Map<String, Object> autoUser = (Map<String, Object>)trip.get('user');
            Map<String, Object> vehicle = (Map<String, Object>)trip.get('vehicle');
                
            trips.add(AutomaticUtils.makeTrip(userIdMap.get((String)autoUser.get('id')), 
                                              vehicleIdMap.get((String)vehicle.get('id')), 
                                              trip));
        }
        
        upsert trips Automatic_Id__c;
        
        // Go to the Trips page
        PageReference pageRef = new PageReference('/' + Trip__c.SObjectType.getDescribe().getKeyPrefix());
        pageRef.setRedirect(true);
        return pageRef;
    }
}