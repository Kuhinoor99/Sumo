trigger CalendarSyncTigger on Calendar_Sync__c (after insert, after update ) {   
   set<id> calIds = new set<id>();
   Calendar_Sync__c calSyncObj = new Calendar_Sync__c();
    for(Calendar_Sync__c obj : trigger.new){
        calIds.add(obj.id);
    }
    if(CheckEventCreation.isTriggerBreak == false ){
        CheckEventCreation.isTriggerBreak = true;       
        if((Trigger.IsInsert ||Trigger.isUpdate) && trigger.isAfter){
         if(!ApexSecurityViolationCtlr.checkAccessible('Sync_Recurring_Events_Appoinments__c, End_Date__c, Start_Date__c, Sync_Direction__c, Sync_Status__c', 'Calendar_Sync__c')) return;
         list<Calendar_Sync__c> calSyncList = [ SELECT Id,Sync_Recurring_Events_Appoinments__c, End_Date__c, Start_Date__c, Sync_Direction__c, Sync_Status__c FROM Calendar_Sync__c WHERE id IN : calIds];
          
          
          if(calSyncList.size() > 0){
              for(Calendar_Sync__c calObj : calSyncList ){
                  if(calObj.Sync_Status__c== 'In Progress' ){
                     if(calobj.Sync_Direction__c == 'Salesforce to SUMO'){
                        
                        Database.executeBatch(new calendarSyncBatchController( calObj.id,calObj.Start_Date__c, calObj.End_Date__c, calobj.Sync_Direction__c,true), 100);
                        if(calobj.Sync_Recurring_Events_Appoinments__c){
                             Database.executeBatch(new SfToSumoRecurringEventBatch( calObj.id,calObj.Start_Date__c, calObj.End_Date__c, calobj.Sync_Direction__c), 1);
                        }
                      }
                      if(calobj.Sync_Direction__c == 'SUMO to Salesforce'){
                          Database.executeBatch(new sumoTOSalesforceSyncBatch( calObj.id,calObj.Start_Date__c, calObj.End_Date__c, calobj.Sync_Direction__c), 100);
                          if(calobj.Sync_Recurring_Events_Appoinments__c){
                              Database.executeBatch(new SumoToSalesforceRecurringSyncBatch( calObj.id,calObj.Start_Date__c, calObj.End_Date__c, calobj.Sync_Direction__c), 1);
                          }
                        } 
                      if(calobj.Sync_Direction__c == 'Both Ways'){
                          Database.executeBatch(new calendarSyncBatchController( calObj.id,calObj.Start_Date__c, calObj.End_Date__c, calobj.Sync_Direction__c,false), 100);
                          Database.executeBatch(new sumoTOSalesforceSyncBatch( calObj.id,calObj.Start_Date__c, calObj.End_Date__c, calobj.Sync_Direction__c), 100);
                          if(calobj.Sync_Recurring_Events_Appoinments__c){
                             Database.executeBatch(new SumoToSalesforceRecurringSyncBatch( calObj.id,calObj.Start_Date__c, calObj.End_Date__c, calobj.Sync_Direction__c), 1);
                             Database.executeBatch(new SfToSumoRecurringEventBatch( calObj.id,calObj.Start_Date__c, calObj.End_Date__c, calobj.Sync_Direction__c), 1);
                         }
                      }     
                  }
              } 
          }           
        }
     }
    
  }