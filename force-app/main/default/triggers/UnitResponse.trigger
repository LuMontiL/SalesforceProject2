trigger UnitResponse on User_Unidad__c (before update, after update) {

    if(trigger.isUpdate && trigger.isBefore){
        UnitResponseService.checkResponses(Trigger.new);
    }
    if(trigger.isUpdate && trigger.isAfter){
        UnitResponseService.checkPointsUser(Trigger.new);
    }


}