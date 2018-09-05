trigger Contact on Contact (after delete, before insert, before update, after insert, after update) {
    
    // SP-202 : Nisar Starts Here 09 November 2015
    // Description : Here we will stop creating a provider without associating an user to it.
    // We are handling this from validation rule but someone can deactivate that validation rule, So one more protection through Trigger.
    // SP-290  is also here
    if(Trigger.isBefore && (Trigger.isInsert ||Trigger.isUpdate)){
        ContactTriggers.validateProvidersWithoutUser(trigger.new, trigger.isInsert, trigger.isUpdate, trigger.isBefore);
    }
    // SP-202 Ends Here
    
    if(trigger.isBefore && trigger.isInsert) {
        ContactTriggers.associateToAccount(trigger.new);
    }
    
    if(trigger.isBefore && trigger.isUpdate) {
        ContactTriggers.updateAccounts(trigger.old, trigger.new);
    }
    
    if(trigger.isAfter && trigger.isUpdate) {
        ContactTriggers.updateNameToAccount(trigger.new);
        ownerChangeUtill obj=new ownerChangeUtill();
        obj.ObjectName='Contact';
        obj.handleOwnerChange(trigger.oldmap,trigger.newmap);// ExpireInvite Code Ticket-461952986
    }
    
    if(trigger.isAfter && trigger.isUpdate) {
        ContactTriggers.deletePersonalAccount(trigger.old, trigger.new);
    }
        
    if(trigger.isAfter && trigger.isDelete) {
        // Ibirds 24 March 2015 Added if condition SAS-353
        if(!Utils.isDeleted)
            ContactTriggers.deleteAccount(trigger.old);
    } 
    // 19 May 2017 : Calling methods to deactivate the active workshifts if Currently Working is unchecked on the provider
    if(Trigger.isAfter && Trigger.isUpdate){
        ContactTriggers.inactiveWorkshifts(Trigger.new, Trigger.oldMap);
    }  
   
}