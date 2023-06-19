//This class contains the necessary structures to show the units and the modules in a LWC.
public class UnitService{
    //Inner class for unit. 
    public class UnitWrapper{
        //Variables
        @AuraEnabled
        public Unidad__c unit; 
        @AuraEnabled
        public List<Pregunta__c> questions;  //questions with related options.
        @AuraEnabled 
        public Boolean isUnitPassed;
    }
    
    //Innner class for trail and it's modules
    public class TrailWrapper{
        //Variables
        @AuraEnabled
        public Trail__c trail; 
        @AuraEnabled
        public Integer progressTrail; //Progress percertage.
        @AuraEnabled
        public List<Modulo__c> modules; //Modules with related units
        @AuraEnabled
        public List<Id> passedModuleIds; //Approved modules Ids -those related to the current trail.
        @AuraEnabled
        public List<Id> passedUnitIds; //Approved units Ids related to the modules. 
    }
    
    //Method to record answers to the units. We'll call this method from the js code 'onClick'
    @AuraEnabled                                           
    public static Boolean saveAnswers(Id unitId, String jsonAnswers){
       
        // Deserialize String JSON into Map<String, String> using  JSON deserializer class.

        Id userId = UserInfo.getUserId();                                                                                        //id, id 
        Map<id, id> answerMap = (Map<id, id>) JSON.deserializeStrict(jsonAnswers, Map<id, id>.class);
        
        // First, we check if there was a previous unitResponse to this unit
        Integer Attempts = 1;
        List<User_Unidad__c> prevUnitResponse = [SELECT Id, Unidad__c, User__c, Estados__c, Puntos__c, Intentos__c 
                                                  FROM User_Unidad__c 
                                                  WHERE User__c = :userId AND Unidad__c = :unitId AND Estados__c = 'Fail'];
        if (prevUnitResponse.size() > 0){
            Attempts = prevUnitResponse.size() + 1;
        }
        
        // Creation of a response to the unit.
        User_Unidad__c unidadConRespuestas = new User_Unidad__c(Name= 'User Unidad con Apex', Unidad__c = unitId, Estados__c = 'Draft', User__c = userId, Intentos__c = Attempts);
        
        //Query the parameter's unit's module
        List<Unidad__c> moduloConfig = [SELECT Id, Modulo__c FROM Unidad__c WHERE Id = :unitId];
        
        
        
        //query User Module where it's user is the one from the parameter and it's module is the first one from the moduloconfig list <Units>
        List<User_Modulo__c> userModulo = [SELECT Id FROM User_Modulo__c WHERE Modulo__c = :moduloConfig[0].Modulo__c AND User__c = :userId];
        
       
        //Validation for good practice. Prevents error
        if(userModulo.size() == 0){  
            User_Modulo__c nuevoUserM = new User_Modulo__c(Modulo__c = moduloConfig[0].Modulo__c, User__c = userId, Estado__c = 'En Progreso');
            insert nuevoUserM;    
            unidadConRespuestas.User_Modulo__c = nuevoUserM.Id;
        	insert unidadConRespuestas; 
        }
        else{
            unidadConRespuestas.User_Modulo__c = userModulo[0].Id;
        	upsert unidadConRespuestas; 
        }
        
        
        // Create User Response por every answered unit
        List<User_Respuesta__c> unitResponses = new List<User_Respuesta__c>();
        
             //id
        for (String questionId : answerMap.keySet()) {
		    
            //selectedOptionId is the user's answer to the question
            Id selectedOptionId = answerMap.get(questionId);
            User_Respuesta__c unitResponse = new User_Respuesta__c(
                User_Unidad__c = unidadConRespuestas.Id,
                Pregunta__c = questionId,
                Respuesta__c = selectedOptionId
            );
            unitResponses.add(unitResponse);
        }
        insert unitResponses;   
        
        //Change status to answered. 
        unidadConRespuestas.Estados__c = 'Answered';    
        update unidadConRespuestas;
        
        //Get the same UserUnit to check that the Trigger performed the method and it's status is now 'Answered'
        User_Unidad__c updatedUr = [SELECT id, Estados__c FROM User_Unidad__c WHERE Id = :unidadConRespuestas.Id];
        
        System.debug(updatedUr.Estados__c);
        //If it was correct, the trigger changed it to 'Success'
        if(updatedUr.Estados__c == 'Success'){     
            return true;
            
        } else{
            return false;
        }
       
    }
    
    
    //Method of inner class for Trail
    @AuraEnabled(cacheable=true)
    public static TrailWrapper getTrailWrapper(Id trailId){ // MÉTODO GET TRAIL WRAPPER
        // Actual User.
    	User actualUser = [select Id from User where Id = :UserInfo.getUserId()];
        
        // Creation of the wrapper that we will return. This is an instance of the inner class
        TrailWrapper wrapper = new TrailWrapper(); 
        
        List<Trail__c> theTrail = [SELECT Id, Name, Detalle__c, Tiempo_Estimado__c, Puntos__c FROM Trail__c WHERE Id = :trailId];
//trail
        wrapper.trail = theTrail[0];
        
        List<User_Trail__c> trailProgress = [SELECT Id, Progreso__c FROM User_Trail__c WHERE Trail__c = :trailId AND User__c = :actualUser.Id];

//progress
        if(trailProgress.size() == 0){
            wrapper.progressTrail = 0;
        }else{
        	wrapper.progressTrail = trailProgress[0].Progreso__c.intValue();            
        }
        
        List<Trail_Modulo__c> trailModules = [SELECT Id, Trail__c, Modulo__c
                                              FROM Trail_Modulo__c
                                              WHERE Trail__c = :trailId];
        
        List<Id> listOfModuleIds = new List<Id>();
        for(Trail_Modulo__c tm : trailModules){
            listOfModuleIds.add(tm.Modulo__c);
        }
        // Modules related to the trail.
        List<Modulo__c> modules = [SELECT Id, Name, Tiempo_Estimado__c, Detalle__c, Active__c, Rol__c, Skill__c, Puntos__c, Unidades_Totales__c,
                                    (SELECT Id, Name, Puntos__c, Tiempo_Estimado__c FROM Unidades__r)
                                   FROM Modulo__c WHERE Id in :listOfModuleIds];
//modules
        wrapper.modules = modules;
        
        List<User_Modulo__c> moduleResponses = [SELECT Id, Modulo__c, (SELECT Id FROM User_Unidades__r) 
                                                FROM User_Modulo__c
                                                WHERE Modulo__c in :modules AND User__c = :actualUser.id AND Estado__c = 'Completado'];
        System.debug(moduleResponses);
        Set<Id> moduleResponseIds = new Set<Id>();
        for(User_Modulo__c mr : moduleResponses){
            moduleResponseIds.add(mr.Modulo__c);
        }
//passed modules
        wrapper.passedModuleIds = new List<Id>(moduleResponseIds);
        
        List<Unidad__c> units = [SELECT Id, Modulo__c, Name, Puntos__c, Tiempo_Estimado__c, Contenido__c
                               FROM Unidad__c
                               WHERE Modulo__c in :listOfModuleIds];
        
        // Set of ids of units
        Set<Id> unitsIds = new Set<Id>();
        for(Unidad__c u : units){
            unitsIds.add(u.Id);
        }
        // UnitResponses list of this units.
        List<User_Unidad__c> UnitResponsesCorrect = [SELECT Id, Unidad__c, Estados__c FROM User_Unidad__c
                                                      WHERE Estados__c = 'Success' AND Unidad__c in :unitsIds];
        Set<Id> unitResponsesId = new Set<Id>();
        for(User_Unidad__c ur : UnitResponsesCorrect){
            unitResponsesId.add(ur.Unidad__c);
        }
        
        // Unidades que el usuario respondio correctamente en el trail
        List<Unidad__c> unitsCorrects = [SELECT Id FROM Unidad__c WHERE Id in :unitResponsesId];
        List<Id> idCorrectUnits = new List<Id>();
        for(Unidad__c u : unitsCorrects){
            idCorrectUnits.add(u.Id);
        }
//passed units
        wrapper.passedUnitIds = idCorrectUnits;
        return wrapper;
    }
    
    //Method of inner class for Unit
    @AuraEnabled(cacheable=true)
    public static UnitWrapper getUnitWrapper(Id unitId){
        UnitWrapper wrapper = new UnitWrapper();
        
        
        Unidad__c unit = [SELECT Id, Name, Puntos__c, Tiempo_Estimado__c, Contenido__c, Modulo__c FROM Unidad__c WHERE Id = :unitId];
//unit
        wrapper.unit = unit;
        
        List<Pregunta__c> questions = [SELECT Id, Name, Contenido__c, Unidad__c, (SELECT Id, Pregunta__c, Contenido_Respuesta__c, Es_Correcta__c, Name FROM Respuestas__r)
                     				   FROM Pregunta__c 
                                       WHERE Unidad__c = :unitId];
//questions
        wrapper.questions = questions;  
        
        User actualUser = [select Id from User where Id = :UserInfo.getUserId()];
        List<User_Unidad__c> ur = [SELECT Id FROM User_Unidad__c WHERE Unidad__c = :unitId AND User__c = :actualUser.Id AND Estados__c = 'Success'];
//is passed
        if(ur.size() == 0){
            wrapper.isUnitPassed = false;
        }else{
            wrapper.isUnitPassed = true;
        }
        
        return wrapper;
    }
         
}