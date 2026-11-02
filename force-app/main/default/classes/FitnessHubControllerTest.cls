@IsTest
private class FitnessHubControllerTest {
    @TestSetup static void setupData(){
        System.runAs(new User(Id=UserInfo.getUserId())) {
            PermissionSet fitness=[SELECT Id FROM PermissionSet WHERE Name='Scone_Fitness_User' LIMIT 1];
            if([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId=:UserInfo.getUserId() AND PermissionSetId=:fitness.Id]==0) insert new PermissionSetAssignment(AssigneeId=UserInfo.getUserId(),PermissionSetId=fitness.Id);
        }
        Exercise__c row=new Exercise__c(Name='Test Row');insert row;
        Workout_Template__c template=new Workout_Template__c(Name='Test Routine');insert template;
        insert new Planned_Exercise__c(Workout_Template__c=template.Id,Exercise__c=row.Id,Exercise_Order__c=1,Target_Sets__c=3,Enter_the_planned_number_of_sets_for_thi__c=10,Min_Reps__c=10,Max_Reps__c=12,Weight_Basis__c='Per dumbbell',Prescription__c='Original prescription');
        Exercise__c carry=new Exercise__c(Name='Test Carry');insert carry;
        insert new Planned_Exercise__c(Workout_Template__c=template.Id,Exercise__c=carry.Id,Exercise_Order__c=2,Target_Sets__c=2,Is_Timed__c=true,Target_Seconds__c=30,Weight_Basis__c='Per dumbbell');
    }
    private static Id start(){return FitnessHubController.startWorkout([SELECT Id FROM Workout_Template__c LIMIT 1].Id);}
    private static void saveAll(Id sessionId){
        for(Workout_Exercise__c e:[SELECT Id,Is_Timed__c FROM Workout_Exercise__c WHERE Workout_Session__c=:sessionId]){
            List<Workout_Set__c> rows=[SELECT Id FROM Workout_Set__c WHERE Workout_Exercise__c=:e.Id];
            for(Workout_Set__c s:rows){s.Weight__c=15;if(e.Is_Timed__c)s.Duration_Seconds__c=30;else s.Reps__c=12;}
            FitnessHubController.saveExercise(sessionId,e.Id,JSON.serialize(rows),true);
        }
    }
    @IsTest static void createsVariableSetsAndReusesUnfinished(){
        // Re-enter the user context so setup-assigned FLS is evaluated.
        System.runAs(new User(Id=UserInfo.getUserId())) {
        Id sessionId=start();System.assertEquals(sessionId,start(),'A repeated start must resume the same session.');
        System.assertEquals(5,[SELECT COUNT() FROM Workout_Set__c]);
        Workout_Exercise__c e=[SELECT Prescription_Snapshot__c FROM Workout_Exercise__c WHERE Is_Timed__c=false LIMIT 1];System.assertEquals('Original prescription',e.Prescription_Snapshot__c);
        Planned_Exercise__c p=[SELECT Id FROM Planned_Exercise__c WHERE Is_Timed__c=false LIMIT 1];p.Prescription__c='Changed template';update p;
        System.assertEquals('Original prescription',[SELECT Prescription_Snapshot__c FROM Workout_Exercise__c WHERE Id=:e.Id].Prescription_Snapshot__c);
        System.assert(FitnessHubController.getHome().contains('Test Routine'));
    
        }
    }
    @IsTest static void savesResumesAndCompletes(){
        // Re-enter the user context so setup-assigned FLS is evaluated.
        System.runAs(new User(Id=UserInfo.getUserId())) {
        Id id=start();FitnessHubController.saveDraft(id,'Saved draft',600);System.assertEquals('Saved draft',[SELECT Workout_Notes__c FROM Workout_Session__c WHERE Id=:id].Workout_Notes__c);saveAll(id);saveAll(id);System.assertEquals(5,[SELECT COUNT() FROM Workout_Set__c],'Resaving must not duplicate sets.');
        System.assert(FitnessHubController.getSession(id).contains('Original prescription'));
        FitnessHubController.finishWorkout(id,'Felt good',1200);FitnessHubController.finishWorkout(id,'Ignored retry',1200);
        Workout_Session__c s=[SELECT Workout_Status__c,Workout_Notes__c,Elapsed_Seconds__c FROM Workout_Session__c WHERE Id=:id];System.assertEquals('Completed',s.Workout_Status__c);System.assertEquals('Felt good',s.Workout_Notes__c);System.assertEquals(1200,s.Elapsed_Seconds__c);
        Boolean rejected=false;try{saveAll(id);}catch(AuraHandledException ex){rejected=true;}System.assert(rejected,'Completed workouts must not be edited through the logger.');
        Id next=start();System.assertNotEquals(id,next);System.assert(FitnessHubController.getSession(next).contains('"considerIncrease":true'),'Prior complete sets with good form should produce a suggestion.');
    
        }
    }
    @IsTest static void rejectsBlankCompletionAndInvalidSetIds(){
        // Re-enter the user context so setup-assigned FLS is evaluated.
        System.runAs(new User(Id=UserInfo.getUserId())) {
        Id id=start();Boolean rejected=false;try{FitnessHubController.finishWorkout(id,'',60);}catch(AuraHandledException ex){rejected=true;}System.assert(rejected);
        Workout_Exercise__c e=[SELECT Id FROM Workout_Exercise__c LIMIT 1];
        Workout_Set__c foreign=[SELECT Id FROM Workout_Set__c WHERE Workout_Exercise__c!=:e.Id LIMIT 1];
        rejected=false;try{FitnessHubController.saveExercise(id,e.Id,JSON.serialize(new List<Workout_Set__c>{foreign}),true);}catch(AuraHandledException ex){rejected=true;}System.assert(rejected);
    
        }
    }
    @IsTest static void skippedSetsAreExplicitAndDoNotCountAsPerformance(){
        // Re-enter the user context so setup-assigned FLS is evaluated.
        System.runAs(new User(Id=UserInfo.getUserId())) {
        Id id=start();Integer performed=0;
        for(Workout_Exercise__c e:[SELECT Id,Is_Timed__c FROM Workout_Exercise__c]){
            List<Workout_Set__c> rows=[SELECT Id FROM Workout_Set__c WHERE Workout_Exercise__c=:e.Id];
            for(Workout_Set__c s:rows){s.Skipped__c=true;if(performed==0){s.Skipped__c=false;if(e.Is_Timed__c)s.Duration_Seconds__c=30;else s.Reps__c=10;performed++;}}
            FitnessHubController.saveExercise(id,e.Id,JSON.serialize(rows),false);
        }
        FitnessHubController.finishWorkout(id,'Partial workout',300);System.assertEquals('Completed',[SELECT Workout_Status__c FROM Workout_Session__c WHERE Id=:id].Workout_Status__c);
        System.assertEquals(4,[SELECT COUNT() FROM Workout_Set__c WHERE Skipped__c=true]);
    
        }
    }
    @IsTest static void rejectsEmptyTemplateAndInvalidTargets(){
        // Re-enter the user context so setup-assigned FLS is evaluated.
        System.runAs(new User(Id=UserInfo.getUserId())) {
        Workout_Template__c empty=new Workout_Template__c(Name='Empty');insert empty;
        Boolean rejected=false;try{FitnessHubController.startWorkout(empty.Id);}catch(AuraHandledException e){rejected=true;}System.assert(rejected);
        Planned_Exercise__c p=[SELECT Id FROM Planned_Exercise__c LIMIT 1];p.Target_Sets__c=11;update p;
        rejected=false;try{start();}catch(AuraHandledException e){rejected=true;}System.assert(rejected);System.assertEquals(0,[SELECT COUNT() FROM Workout_Session__c]);
    
        }
    }
    @IsTest static void rejectsNegativeAndDuplicateSetInput(){
        // Re-enter the user context so setup-assigned FLS is evaluated.
        System.runAs(new User(Id=UserInfo.getUserId())) {
        Id id=start();Workout_Exercise__c e=[SELECT Id FROM Workout_Exercise__c WHERE Is_Timed__c=false LIMIT 1];
        List<Workout_Set__c> rows=[SELECT Id FROM Workout_Set__c WHERE Workout_Exercise__c=:e.Id];rows[0].Weight__c=-1;
        Boolean rejected=false;try{FitnessHubController.saveExercise(id,e.Id,JSON.serialize(rows),false);}catch(AuraHandledException ex){rejected=true;}System.assert(rejected);
        rows[0].Weight__c=0;rows.add(rows[0]);rejected=false;try{FitnessHubController.saveExercise(id,e.Id,JSON.serialize(rows),false);}catch(AuraHandledException ex){rejected=true;}System.assert(rejected);
    
        }
    }
}
