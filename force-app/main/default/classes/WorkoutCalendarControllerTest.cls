@IsTest
private class WorkoutCalendarControllerTest {
    @IsTest
    static void returnsNoSessionsInIsolatedTest() {
        Test.startTest();
        List<Workout_Session__c> results = WorkoutCalendarController.getCompletedSessions();
        Test.stopTest();
        System.assertEquals(0, results.size(), 'No sessions exist in test isolation.');
    }
}
