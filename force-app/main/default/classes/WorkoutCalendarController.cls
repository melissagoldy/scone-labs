public with sharing class WorkoutCalendarController {
    @AuraEnabled(cacheable=true)
    public static List<Workout_Session__c> getCompletedSessions() {
        return [
            SELECT Id, Name, Workout_Date__c, Workout_Status__c,
                   Workout_Template__r.Name
            FROM Workout_Session__c
            WHERE OwnerId = :UserInfo.getUserId()
              AND Workout_Status__c = 'Completed'
              AND Workout_Date__c >= 2026-11-16
              AND Workout_Date__c <= 2027-02-07
            ORDER BY Workout_Date__c ASC
            LIMIT 200
        ];
    }
}
