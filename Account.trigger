trigger Account on Account (after delete, after insert, after undelete, after update, before delete, before insert, before update) {

    
    if (trigger.isBefore && trigger.isDelete) {
        AccountTriggers.deleteAccount(trigger.old);
    }   
    
    
    if (trigger.isBefore && trigger.isInsert) {
        AccountTriggers.insertAccount(trigger.new);
    }   
    
    
    if (trigger.isBefore && trigger.isUpdate) {
        AccountTriggers.updateAccount(trigger.new);
    }   

}