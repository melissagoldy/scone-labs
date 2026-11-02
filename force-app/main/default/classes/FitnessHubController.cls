public with sharing class FitnessHubController {
    // JSON is the boundary so LWC doesn't depend on Apex inner-class serialization.
    private static final Integer MAX_SETS = 10;
    private static AuraHandledException fail(String message) { return new AuraHandledException(message); }
    private static Map<String,Object> recordMap(SObject row) {
        return (Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(row));
    }
    @AuraEnabled
    public static String getHome() {
        List<Workout_Template__c> templates = [SELECT Id, Name, Template_Description__c FROM Workout_Template__c WITH USER_MODE ORDER BY Name LIMIT 100];
        List<Workout_Session__c> sessions = [SELECT Id, Name, Workout_Date__c, Workout_Status__c, Workout_Template__r.Name, Elapsed_Seconds__c FROM Workout_Session__c WHERE OwnerId = :UserInfo.getUserId() WITH USER_MODE ORDER BY Workout_Date__c DESC, CreatedDate DESC LIMIT 20];
        List<Workout_Session__c> unfinished = [SELECT Id, Name, Workout_Date__c, Workout_Status__c, Workout_Template__r.Name FROM Workout_Session__c WHERE OwnerId = :UserInfo.getUserId() AND Workout_Status__c = 'Started' WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 50];
        return JSON.serialize(new Map<String,Object>{'templates'=>templates,'sessions'=>sessions,'unfinished'=>unfinished});
    }
    private static Workout_Session__c ownedSession(Id sessionId, Boolean lockRow) {
        List<Workout_Session__c> rows;
        if (lockRow) rows = [SELECT Id, OwnerId, Workout_Status__c, Started_At__c FROM Workout_Session__c WHERE Id = :sessionId WITH USER_MODE FOR UPDATE];
        else rows = [SELECT Id, OwnerId, Workout_Status__c, Started_At__c FROM Workout_Session__c WHERE Id = :sessionId WITH USER_MODE];
        if (rows.isEmpty() || rows[0].OwnerId != UserInfo.getUserId()) throw fail('This workout is unavailable for your user.');
        return rows[0];
    }
    @AuraEnabled
    public static Id startWorkout(Id templateId) {
        // Serialize starts on a template. A repeated tap returns the existing unfinished session.
        List<Workout_Template__c> templates = [SELECT Id FROM Workout_Template__c WHERE Id = :templateId WITH USER_MODE FOR UPDATE];
        if (templates.isEmpty()) throw fail('Choose an available workout template.');
        List<Workout_Session__c> existing = [SELECT Id FROM Workout_Session__c WHERE Workout_Template__c = :templateId AND OwnerId = :UserInfo.getUserId() AND Workout_Status__c = 'Started' WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 1];
        if (!existing.isEmpty()) return existing[0].Id;
        List<Planned_Exercise__c> plan = [SELECT Id, Exercise__c, Exercise_Order__c, Target_Sets__c, Enter_the_planned_number_of_sets_for_thi__c, Prescription__c, Min_Reps__c, Max_Reps__c, Is_Timed__c, Target_Seconds__c, Rest_Seconds__c, Weight_Basis__c FROM Planned_Exercise__c WHERE Workout_Template__c = :templateId WITH USER_MODE ORDER BY Exercise_Order__c, CreatedDate LIMIT 31];
        if (plan.isEmpty() || plan.size() > 30) throw fail('A template needs between 1 and 30 exercises.');
        for (Planned_Exercise__c p : plan) {
            if (p.Exercise__c == null || p.Target_Sets__c == null || p.Target_Sets__c < 1 || p.Target_Sets__c > MAX_SETS) throw fail('Each planned exercise needs an exercise and 1 to 10 target sets.');
            if (p.Min_Reps__c != null && p.Max_Reps__c != null && p.Min_Reps__c > p.Max_Reps__c) throw fail('Minimum reps cannot exceed maximum reps.');
            if (p.Is_Timed__c && (p.Target_Seconds__c == null || p.Target_Seconds__c <= 0)) throw fail('Timed exercises need target seconds.');
        }
        Savepoint checkpoint = Database.setSavepoint();
        try {
            Workout_Session__c session = new Workout_Session__c(Workout_Template__c=templateId,Workout_Date__c=Date.today(),Workout_Status__c='Started',Started_At__c=System.now());
            insert as user session;
            List<Workout_Exercise__c> exercises = new List<Workout_Exercise__c>();
            for (Planned_Exercise__c p : plan) exercises.add(new Workout_Exercise__c(Workout_Session__c=session.Id,Exercise__c=p.Exercise__c,Exercise_Order__c=p.Exercise_Order__c,Target_Sets__c=p.Target_Sets__c,Target_Reps__c=p.Enter_the_planned_number_of_sets_for_thi__c,Min_Reps__c=p.Min_Reps__c,Max_Reps__c=p.Max_Reps__c,Is_Timed__c=p.Is_Timed__c,Target_Seconds__c=p.Target_Seconds__c,Rest_Seconds__c=p.Rest_Seconds__c,Weight_Basis__c=p.Weight_Basis__c,Prescription_Snapshot__c=p.Prescription__c));
            insert as user exercises;
            List<Workout_Set__c> sets = new List<Workout_Set__c>();
            for (Workout_Exercise__c e : exercises) for (Integer n=1; n<=e.Target_Sets__c; n++) sets.add(new Workout_Set__c(Workout_Exercise__c=e.Id,Set_Number__c=n));
            insert as user sets;
            return session.Id;
        } catch (Exception error) {
            Database.rollback(checkpoint);
            throw fail('Unable to start workout: ' + error.getMessage());
        }
    }
    @AuraEnabled
    public static String getSession(Id sessionId) {
        ownedSession(sessionId,false);
        Workout_Session__c session = [SELECT Id, Name, Workout_Date__c, Workout_Status__c, Workout_Notes__c, Workout_Template__r.Name, Started_At__c, Completed_At__c, Elapsed_Seconds__c FROM Workout_Session__c WHERE Id=:sessionId WITH USER_MODE];
        List<Workout_Exercise__c> exercises = [SELECT Id, Exercise__c, Exercise__r.Name, Exercise__r.Form_Notes__c, Exercise__r.Video_URL__c, Exercise_Order__c, Target_Sets__c, Target_Reps__c, Min_Reps__c, Max_Reps__c, Is_Timed__c, Target_Seconds__c, Rest_Seconds__c, Weight_Basis__c, Prescription_Snapshot__c, Form_Confirmed__c FROM Workout_Exercise__c WHERE Workout_Session__c=:sessionId WITH USER_MODE ORDER BY Exercise_Order__c, CreatedDate, Id];
        Set<Id> exerciseIds=new Set<Id>(); Set<Id> currentIds=new Set<Id>();
        for (Workout_Exercise__c e:exercises) {exerciseIds.add(e.Exercise__c);currentIds.add(e.Id);}
        List<Workout_Set__c> sets = [SELECT Id, Workout_Exercise__c, Set_Number__c, Weight__c, Reps__c, Duration_Seconds__c, Skipped__c FROM Workout_Set__c WHERE Workout_Exercise__c IN :currentIds WITH USER_MODE ORDER BY Set_Number__c, Id];
        List<Workout_Exercise__c> history = [SELECT Id, Exercise__c, Is_Timed__c, Weight_Basis__c, Form_Confirmed__c, Workout_Session__r.Workout_Date__c FROM Workout_Exercise__c WHERE Exercise__c IN :exerciseIds AND Workout_Session__c != :sessionId AND Workout_Session__r.OwnerId=:UserInfo.getUserId() AND Workout_Session__r.Workout_Status__c='Completed' AND Workout_Session__r.Workout_Date__c <= :session.Workout_Date__c WITH USER_MODE ORDER BY Workout_Session__r.Workout_Date__c DESC, CreatedDate DESC LIMIT 2000];
        Map<Id,Workout_Exercise__c> histories = new Map<Id,Workout_Exercise__c>(history);
        List<Workout_Set__c> oldSets = [SELECT Id, Workout_Exercise__c, Set_Number__c, Weight__c, Reps__c, Duration_Seconds__c, Skipped__c FROM Workout_Set__c WHERE Workout_Exercise__c IN :histories.keySet() WITH USER_MODE ORDER BY Set_Number__c, Id LIMIT 10000];
        Map<Id,List<Workout_Set__c>> byParent=new Map<Id,List<Workout_Set__c>>();
        for (Workout_Set__c s:oldSets) {if(!byParent.containsKey(s.Workout_Exercise__c))byParent.put(s.Workout_Exercise__c,new List<Workout_Set__c>());byParent.get(s.Workout_Exercise__c).add(s);}
        List<Object> cards=new List<Object>();
        for (Workout_Exercise__c e:exercises) {
            Map<String,Object> card=recordMap(e);List<Workout_Set__c> rows=new List<Workout_Set__c>();
            for(Workout_Set__c s:sets)if(s.Workout_Exercise__c==e.Id)rows.add(s);
            card.put('sets',rows);card.put('historyLimited',history.size()==2000 || oldSets.size()==10000);
            List<Workout_Set__c> lastSets=new List<Workout_Set__c>();Date lastDate;Boolean previousForm=false;Decimal bestWeight;
            for(Workout_Exercise__c h:history) {
                if(h.Exercise__c!=e.Exercise__c || h.Is_Timed__c!=e.Is_Timed__c || h.Weight_Basis__c!=e.Weight_Basis__c || !byParent.containsKey(h.Id))continue;
                List<Workout_Set__c> valid=new List<Workout_Set__c>();
                for(Workout_Set__c s:byParent.get(h.Id))if(!s.Skipped__c && ((e.Is_Timed__c && s.Duration_Seconds__c>0)||(!e.Is_Timed__c && s.Reps__c>0))) {valid.add(s);if(s.Weight__c!=null&&(bestWeight==null||s.Weight__c>bestWeight))bestWeight=s.Weight__c;}
                if(lastDate==null&&!valid.isEmpty()){lastDate=h.Workout_Session__r.Workout_Date__c;lastSets=valid;previousForm=h.Form_Confirmed__c;}
            }
            Boolean ready=!e.Is_Timed__c && e.Max_Reps__c!=null && e.Weight_Basis__c!=null && previousForm && e.Target_Sets__c!=null && lastSets.size()>=e.Target_Sets__c;
            Decimal weight;
            for(Workout_Set__c s:lastSets){if(weight==null)weight=s.Weight__c;if(s.Weight__c==null||s.Weight__c!=weight||s.Reps__c==null||s.Reps__c<e.Max_Reps__c)ready=false;}
            card.put('previousSets',lastSets);card.put('previousDate',lastDate);card.put('bestWeight',bestWeight);card.put('considerIncrease',ready);cards.add(card);
        }
        return JSON.serialize(new Map<String,Object>{'session'=>session,'exercises'=>cards});
    }
    @AuraEnabled
    public static void saveExercise(Id sessionId, Id workoutExerciseId, String setsJson, Boolean formConfirmed) {
        Workout_Session__c session=ownedSession(sessionId,true);
        if(session.Workout_Status__c=='Completed')throw fail('Completed workouts are read-only in this logger.');
        List<Workout_Exercise__c> exercises=[SELECT Id, Is_Timed__c FROM Workout_Exercise__c WHERE Id=:workoutExerciseId AND Workout_Session__c=:sessionId WITH USER_MODE];
        if(exercises.isEmpty())throw fail('Exercise does not belong to this workout.');
        List<Workout_Set__c> submitted;
        try{submitted=(List<Workout_Set__c>)JSON.deserialize(setsJson,List<Workout_Set__c>.class);}catch(Exception e){throw fail('Invalid set data.');}
        if(submitted==null||submitted.size()>MAX_SETS)throw fail('Invalid number of sets.');
        Map<Id,Workout_Set__c> allowed=new Map<Id,Workout_Set__c>([SELECT Id FROM Workout_Set__c WHERE Workout_Exercise__c=:workoutExerciseId WITH USER_MODE]);
        Set<Id> seen=new Set<Id>();List<Workout_Set__c> updates=new List<Workout_Set__c>();
        for(Workout_Set__c s:submitted){
            if(s.Id==null||!allowed.containsKey(s.Id)||seen.contains(s.Id))throw fail('Invalid or duplicate set.');seen.add(s.Id);
            if((s.Weight__c!=null&&s.Weight__c<0)||(s.Reps__c!=null&&(s.Reps__c<0||s.Reps__c>999||s.Reps__c!=s.Reps__c.setScale(0)))||(s.Duration_Seconds__c!=null&&(s.Duration_Seconds__c<0||s.Duration_Seconds__c!=s.Duration_Seconds__c.setScale(0))))throw fail('Use nonnegative weights and whole-number reps or seconds.');
            updates.add(new Workout_Set__c(Id=s.Id,Weight__c=s.Weight__c,Reps__c=exercises[0].Is_Timed__c?null:s.Reps__c,Duration_Seconds__c=exercises[0].Is_Timed__c?s.Duration_Seconds__c:null,Skipped__c=s.Skipped__c==true));
        }
        if(seen.size()!=allowed.size())throw fail('Refresh the workout before saving. Its sets have changed.');
        Savepoint checkpoint=Database.setSavepoint();
        try {update as user updates;update as user new Workout_Exercise__c(Id=workoutExerciseId,Form_Confirmed__c=formConfirmed==true);}
        catch(Exception e){Database.rollback(checkpoint);throw fail('Unable to save exercise: '+e.getMessage());}
    }
    @AuraEnabled
    public static void saveDraft(Id sessionId, String notes, Integer elapsedSeconds) {
        Workout_Session__c session=ownedSession(sessionId,true);
        if(session.Workout_Status__c=='Completed')throw fail('Completed workouts are read-only in this logger.');
        if(notes!=null&&notes.length()>32768)throw fail('Workout notes are too long.');
        if(elapsedSeconds!=null&&(elapsedSeconds<0||elapsedSeconds>86400))throw fail('Duration must be between 0 and 24 hours.');
        update as user new Workout_Session__c(Id=sessionId,Workout_Notes__c=notes,Elapsed_Seconds__c=elapsedSeconds);
    }
    @AuraEnabled
    public static void finishWorkout(Id sessionId, String notes, Integer elapsedSeconds) {
        Workout_Session__c session=ownedSession(sessionId,true);
        if(session.Workout_Status__c=='Completed')return;
        List<Workout_Exercise__c> exercises=[SELECT Id, Is_Timed__c, Target_Sets__c FROM Workout_Exercise__c WHERE Workout_Session__c=:sessionId WITH USER_MODE];
        if(exercises.isEmpty())throw fail('This workout has no exercises.');
        Map<Id,Workout_Exercise__c> byId=new Map<Id,Workout_Exercise__c>(exercises);
        Map<Id,Integer> counts=new Map<Id,Integer>();Integer performed=0;
        for(Workout_Set__c s:[SELECT Workout_Exercise__c, Reps__c, Duration_Seconds__c, Skipped__c FROM Workout_Set__c WHERE Workout_Exercise__c IN :byId.keySet() WITH USER_MODE]){
            if(!counts.containsKey(s.Workout_Exercise__c))counts.put(s.Workout_Exercise__c,0);counts.put(s.Workout_Exercise__c,counts.get(s.Workout_Exercise__c)+1);
            Boolean valid=byId.get(s.Workout_Exercise__c).Is_Timed__c?s.Duration_Seconds__c>0:s.Reps__c>0;
            if(!s.Skipped__c&&!valid)throw fail('Enter reps or seconds for every set, or explicitly skip it.');
            if(!s.Skipped__c&&valid)performed++;
        }
        for(Workout_Exercise__c e:exercises)if(!counts.containsKey(e.Id)||e.Target_Sets__c==null||counts.get(e.Id)!=e.Target_Sets__c)throw fail('The saved set count does not match the exercise target.');
        if(performed==0)throw fail('Log at least one performed set before completing.');
        if(notes!=null&&notes.length()>32768)throw fail('Workout notes are too long.');
        if(elapsedSeconds!=null&&(elapsedSeconds<0||elapsedSeconds>86400))throw fail('Duration must be between 0 and 24 hours.');
        update as user new Workout_Session__c(Id=sessionId,Workout_Status__c='Completed',Workout_Notes__c=notes,Completed_At__c=System.now(),Elapsed_Seconds__c=elapsedSeconds);
    }
}
