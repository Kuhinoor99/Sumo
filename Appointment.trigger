trigger Appointment on Event__c (after delete, after insert, after undelete, after update, before delete, before insert, before update) {
    if (CheckEventCreation.isAppTriggerBreak || CheckEventCreation.isTriggerBreak || CheckEventCreation.manageTooManySoqlInUpdated){
        return;
    }    
    
    if(Trigger.isUpdate && Trigger.isAfter){
        Set<Id> sAppointmentToUpdateParticipantInfo = new Set<Id>();
        Set<Id> appointmentToHandleChatter=new Set<Id>();
        Set<Id> processIdSet=new Set<Id>();
        for(Event__c appointmentObj : Trigger.new){
            if(appointmentObj.Assigned_To__c != NULL && appointmentObj.Assigned_To__c != Trigger.oldMap.get(appointmentObj.id).Assigned_To__c){
                sAppointmentToUpdateParticipantInfo.add(appointmentObj.id);
                
                if(appointmentObj.IsSelfSchedule__c && Trigger.oldMap.get(appointmentObj.id).Assigned_To__c!=null){
                    appointmentToHandleChatter.add(appointmentObj.id);
                    processIdSet.add(appointmentObj.Self_Scheduling_Site__c);
                }
            }
        }
        if(sAppointmentToUpdateParticipantInfo.size() > 0){
            EventParticipantHandler.updateAppointmentParticipantInfo(sAppointmentToUpdateParticipantInfo);
        }
        
        if(appointmentToHandleChatter.size() > 0){
            ChatterHandler(appointmentToHandleChatter,processIdSet);
        }
    } 
    
    if(trigger.isBefore && trigger.isDelete){
        
        CheckEventCreation.appointmentTrigger = true;
        
        EventRecurrenceTrigger.deleteChildren(trigger.old);
        
        if(EventRecurrenceTrigger.isDeleteEventToRec == false)EventRecurrenceTrigger.deleteMapedEvent(trigger.old);
    }
    
    if(trigger.isBefore && (trigger.isInsert || trigger.isUpdate)) {
        
        //ABHISHEK:UPDATE SFDC EVENT ID TO APPOINTMENT BACK
        if(trigger.isUpdate){
            EventParticipantHandler.updateSFEventIdonAppointment(trigger.newMap);
        }
        //Manage DST
        if(trigger.isInsert){
            EventRecurrenceTrigger.manageDst(trigger.new ,Trigger.isInsert);
        }
        
        //Set Label
        EventRecurrenceLabelTrigger.setLabel(trigger.new,trigger.newMap,trigger.isUpdate); 
         
        //Set Appointment Notification
        if(!EventRecurrenceTrigger.isCancelParentUpdate){
            
            AppointmentNotificationTrigger.setNotification(trigger.new); 
        }
        
        
    } 
    
    if(trigger.isAfter && trigger.isInsert && CheckEventCreation.isChildCreated == false) {
        
        EventRecurrenceTrigger.create(trigger.new,Trigger.isInsert); 
        CheckEventCreation.isChildCreated = true;
        
                   
    }
    
    if(trigger.isAfter && trigger.isUpdate && CheckEventCreation.isChildUpdated == false){
        
        
        
        if(!EventRecurrenceTrigger.isCancelParentUpdate ){
            
            
            // // Commented this debug because of security review.
            EventRecurrenceTrigger.updateRecurrence(trigger.new, trigger.old);
            
            CheckEventCreation.isChildUpdated = true;
        }
    }
    
    if(trigger.isAfter && (trigger.isInsert || trigger.isUpdate)) {
        
        //SUMO India Akshay Dhiman Update the ServiceName field on AppointmentParticipant Start LeanKit - 321666636
        if(Utils.runOnce()) {            
            List<EventParticipant__c> eventParticipantsToUpdate = new List<EventParticipant__c>();
            List<Event__c> evntWithServiceChanged = new List<Event__c>();
            for(Event__c evnts : trigger.new) {
                if(trigger.isInsert) {
                    evntWithServiceChanged.add(evnts);
                }
                if(trigger.isUpdate) {
                    if(trigger.oldMap.get(evnts.Id).Service_Text__c != trigger.newMap.get(evnts.Id).Service_Text__c) {
                        evntWithServiceChanged.add(evnts);
                    }
                }
            }
            
                if(!ApexSecurityViolationCtlr.checkAccessible('Event__c,ServiceName__c', 'EventParticipant__c')) return;
                eventParticipantsToUpdate = [SELECT Event__c, ServiceName__c FROM EventParticipant__c WHERE Event__c IN: evntWithServiceChanged];
                
                if(!ApexSecurityViolationCtlr.checkCRUD('ServiceName__c', 'EventParticipant__c', false, true )) return;
                
                List<EventParticipant__c> partToBeUpdated = new List<EventParticipant__c>();
                for(Event__c evnts : evntWithServiceChanged) {
                    for(EventParticipant__c evPart : eventParticipantsToUpdate) {
                        if(evPart.Event__c == evnts.Id) {
                            evPart.ServiceName__c = evnts.Service_Text__c;
                            partToBeUpdated.add(evPart);
                        }
                    }
                }
                if(partToBeUpdated.size() > 0) {
                    if(Schema.sObjectType.EventParticipant__c.isUpdateable()) update partToBeUpdated;
                }
            
        }
        
        //SUMO India Akshay Dhiman Update the ServiceName field on AppointmentParticipant End  LeanKit - 321666636
        
        
        EventReminderDateTrigger.putReminderDate(trigger.new); 
        
    }
    
    if(trigger.isAfter && trigger.isUpdate){
        
        if(!EventRecurrenceTrigger.isCancelParentUpdate){
            
            EventTriggers.setFlagToParticipants(trigger.old, trigger.new);
            
        }
    }
    /* Code Added By Ramesh-06 April 2017 .Assigned changes chatter Post and Case owner Change ticket*/
    public void ChatterHandler(Set<Id> appointmentIds,Set<Id> setProcessId){
        Set<Id> IdSet=appointmentIds;
        List<Case> caseListToUpdate=new List<Case>();
        
        Map<Id,Boolean>procesChatterMap=new Map<Id,Boolean>();
        for(Scheduling_Setting_Line_Item__c ssliChatterObject : [SELECT Id,Online_Scheduling_Process__c FROM Scheduling_Setting_Line_Item__c WHERE Type__c = 'Chatter Post Object' AND Online_Scheduling_Process__c IN :setProcessId]){
                        procesChatterMap.put(ssliChatterObject.Online_Scheduling_Process__c,true);
                    }
        for(Event__c ev:[select Edit_Url__c,Case__c,Assigned_To__c,Assigned_To__r.User__c,Self_Scheduling_Site__c,Self_Scheduling_Site__r.Chatter_Alert_Enabled__c,Self_Scheduling_Site__r.Auto_Change_Case_Owner__c,Self_Scheduling_Site__r.Chatter_Default_Message__c,IsSelfSchedule__c from Event__c where Id IN :IdSet and IsSelfSchedule__c=true and Assigned_To__c!=null and Self_Scheduling_Site__c!=null and Assigned_To__r.User__c!=null]){
                 
                 if(ev.Self_Scheduling_Site__r.Chatter_Alert_Enabled__c==true &&ev.Self_Scheduling_Site__r.Chatter_Default_Message__c!=null && ev.Self_Scheduling_Site__r.Chatter_Default_Message__c!=''){
                        
                        ConnectApi.FeedItemInput feedItemInput = new ConnectApi.FeedItemInput();
                        ConnectApi.MentionSegmentInput mentionSegmentInput = new ConnectApi.MentionSegmentInput();
                        ConnectApi.MessageBodyInput messageBodyInput = new ConnectApi.MessageBodyInput();
                        ConnectApi.TextSegmentInput textSegmentInput = new ConnectApi.TextSegmentInput();
                                            
                        ConnectApi.LinkCapabilityInput linkInput = new ConnectApi.LinkCapabilityInput();
                        
                        ConnectApi.FeedElementCapabilitiesInput capabilities = new ConnectApi.FeedElementCapabilitiesInput();
                                            
                        
                        
                        
                        
                        messageBodyInput.messageSegments = new List<ConnectApi.MessageSegmentInput>();
                        
                        mentionSegmentInput.id = ev.Assigned_To__r.User__c;
                        messageBodyInput.messageSegments.add(mentionSegmentInput);
                        
                        textSegmentInput.text = ev.Self_Scheduling_Site__r.Chatter_Default_Message__c; 
                        messageBodyInput.messageSegments.add(textSegmentInput);
                        
                        feedItemInput.body = messageBodyInput;
                        feedItemInput.feedElementType = ConnectApi.FeedElementType.FeedItem;
                        feedItemInput.subjectId = ev.id; 
                        linkInput.urlName = 'Edit URL';
                        linkInput.url = ev.Edit_Url__c;
                        capabilities.link = linkInput;
                        
                        
                        feedItemInput.capabilities = capabilities;
                        
                        if(!system.test.isRunningTest())
                            ConnectApi.FeedElement feedElement = ConnectApi.ChatterFeeds.postFeedElement(Network.getNetworkId(), feedItemInput, null);
                      }
                    /* code Start for Owner change From Here */  
                   if(ev.Self_Scheduling_Site__r.Auto_Change_Case_Owner__c==true && ev.Case__c!=null){
                        
                        Case c=new case(Id=ev.case__c);
                        c.ownerId=ev.Assigned_To__r.User__c;
                        caseListToUpdate.add(c);
                   }
             }
             
             if(caseListToUpdate.size()>0){
                try{
                     if(Schema.sObjectType.Case.isUpdateable())
                        update caseListToUpdate;
                     }catch(Exception e){
                        
                    }
                }
    }
    /* Code Added For Chatter Post */
   
    /*Code Added for Making Rollup count on Appointment Invite Object*/
    if(trigger.isAfter &&(trigger.isDelete || trigger.isUpdate || trigger.isInsert || trigger.isUnDelete)){
             Event__c[] objects = null;
             if (Trigger.isDelete) {
                 objects = Trigger.old;
                 
                 EventParticipantHandler.deleteSyncSFDCEventsOnAppointmentDelete(trigger.oldMap.keySet());
             } else {
                /*
                    Handle any filtering required, specially on Trigger.isUpdate event. If the rolled up fields
                    are not changed, then please make sure you skip the rollup operation.
                    We are not adding that for sake of similicity of this illustration.
                */ 
                objects = Trigger.new;
             }
        
             /*
              First step is to create a context for LREngine, by specifying parent and child objects and
              lookup relationship field name
             */
             LREngine.Context ctx = new LREngine.Context(Appointment_Invite__c.SobjectType, 
                                                    Event__c.SobjectType,  
                                                    Schema.SObjectType.Event__c.fields.Appointment_Invite__c
                                                    ,'IsSelfSchedule__c=true'
                                                    );     
             /*
              Next, one can add multiple rollup fields on the above relationship. 
              Here specify 
               1. The field to aggregate in child object
               2. The field to which aggregated value will be saved in master/parent object
               3. The aggregate operation to be done i.e. SUM, AVG, COUNT, MIN/MAX
             */ 
             ctx.add(
                    new LREngine.RollupSummaryField(
                                                    Schema.SObjectType.Appointment_Invite__c.fields.Scheduled_Appointment_Count__c,
                                                    Schema.SObjectType.Event__c.fields.Id,
                                                    LREngine.RollupOperation.Count
                                                     
                                                 )); 
                                              
        
             /* 
              Calling rollup method returns in memory master objects with aggregated values in them. 
              Please note these master records are not persisted back, so that client gets a chance 
              to post process them after rollup
              */ 
             
             List<Sobject> masterwithIdOnly=new List<Sobject>();
             for(Sobject masters : LREngine.rollUp(ctx, objects)){
                if(masters.id!=null)
                masterwithIdOnly.add(masters);
             }
             if(masterwithIdOnly.size()>0)
                update masterwithIdOnly;
            
     }
    
}