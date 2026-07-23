global with sharing class SaveWorkoutExerciseSets {

    global class Request {
        @InvocableVariable(required=true)
        public Id workoutExerciseId;

        @InvocableVariable
        public Decimal set1Weight;

        @InvocableVariable
        public Integer set1Reps;

        @InvocableVariable
        public Decimal set2Weight;

        @InvocableVariable
        public Integer set2Reps;
    }

    global class Response {
        @InvocableVariable
        public String resultMessage;
    }

    @InvocableMethod(
        label='Save Workout Exercise Sets'
        description='Updates set 1 and set 2 weight and reps for a workout exercise.'
    )
    global static List<Response> saveSets(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            List<Workout_Set__c> setsToUpdate = [
                SELECT Id, Set_Number__c, Weight__c, Reps__c
                FROM Workout_Set__c
                WHERE Workout_Exercise__c = :req.workoutExerciseId
                AND Set_Number__c IN (1, 2)
                ORDER BY Set_Number__c
            ];

            for (Workout_Set__c ws : setsToUpdate) {
                Integer setNum = Integer.valueOf(ws.Set_Number__c);

                if (setNum == 1) {
                    if (req.set1Weight != null) {
                        ws.Weight__c = req.set1Weight;
                    }
                    if (req.set1Reps != null) {
                        ws.Reps__c = req.set1Reps;
                    }
                } else if (setNum == 2) {
                    if (req.set2Weight != null) {
                        ws.Weight__c = req.set2Weight;
                    }
                    if (req.set2Reps != null) {
                        ws.Reps__c = req.set2Reps;
                    }
                }
            }

            update setsToUpdate;

            Response res = new Response();
            res.resultMessage = 'Updated ' + setsToUpdate.size() + ' sets.';
            responses.add(res);
        }

        return responses;
    }
}