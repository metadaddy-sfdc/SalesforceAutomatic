/***************************************
* AutomaticTripFinishedHandler.cls
* Handles the trip:finished automatic
* webhook callout type
***************************************/
public with sharing class AutomaticTripFinishedHandler implements IAutomaticHandler {
	public Boolean handleWebhook(Map<String, Object> webhookRequestBody) {
    	Map<String, Object> vehicle = (Map<String, Object>)webhookRequestBody.get('vehicle');
    	Map<String, Object> trip = (Map<String, Object>)webhookRequestBody.get('trip');
    	Map<String, Object> autoUser = (Map<String, Object>)webhookRequestBody.get('user');

    	String vehicleId = (String)vehicle.get('id');
    	String autoUserId = (String)autoUser.get('id');
        
    	Vehicle__c v;
    	// Let's see if we have an existing vehicle with the request body's vehicle's automatic id (which
    	// we've set as a unique, external id in salesforce)
    	try {
			v = [select id, name, automatic_id__c, year__c, make__c, model__c, color__c 
                 from Vehicle__c 
                 where automatic_id__c = :vehicleId];
    	} catch (Exception e) {
    		// If not, insert a new vehicle
    		insert AutomaticUtils.makeVehicle(vehicle);
    	}

    	// Now let's get the driver of the vehicle, found by matching the request body user id with an authentication custom setting
    	// for the Automatic user id we saved. We're querying our hierarchical custom object using SOQL here, rather than the
    	// regular getInstance method
    	User user;
    	try {
    		user = [select id from User where Automatic_Id__c = :autoUserId];
    	}
    	// For our purposes, we won't handle the case where we can't find a user, and will just leave this info blank in our
    	// final saved record
    	Catch (Exception e) {
    	}

    	// Now let'e create a new trip, populating it with information from the request body. (Note all the casting we
    	// have to do.)
    	try {
    		insert AutomaticUtils.makeTrip(user, v, trip);
    	}
    	Catch (Exception e) {
    		return false;
    	}
		return true;
	}
}