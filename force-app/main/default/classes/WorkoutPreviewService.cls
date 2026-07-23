global with sharing class WorkoutPreviewService {

    global class Request {
        @InvocableVariable(required=true)
        public Id workoutTemplateId;
    }

    global class Response {
        @InvocableVariable
        public String previewText;
    }

    @InvocableMethod(
        label='Get Workout Preview'
        description='Returns formatted last workout preview text for a selected workout template.'
    )
    global static List<Response> getWorkoutPreview(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();

            List<Workout_Session__c> sessions = [
                SELECT Id, Name, Workout_Date__c, Workout_Template__r.Name
                FROM Workout_Session__c
                WHERE Workout_Template__c = :req.workoutTemplateId
                AND Workout_Status__c = 'Completed'
                ORDER BY Workout_Date__c DESC
                LIMIT 1
            ];

            if (sessions.isEmpty()) {
                res.previewText = 'No completed workout found yet.';
                responses.add(res);
                continue;
            }

            Workout_Session__c lastSession = sessions[0];

            List<Workout_Set__c> sets = [
                SELECT Set_Number__c,
                       Weight__c,
                       Reps__c,
                       Workout_Exercise__r.Exercise_Order__c,
                       Workout_Exercise__r.Exercise__r.Name
                FROM Workout_Set__c
                WHERE Workout_Exercise__r.Workout_Session__c = :lastSession.Id
                ORDER BY Workout_Exercise__r.Exercise_Order__c, Set_Number__c
            ];

            String preview = '';
            preview += lastSession.Workout_Template__r.Name + '\n';
            preview += 'Last Workout: ' + String.valueOf(lastSession.Workout_Date__c) + '\n\n';

            String currentExercise = '';

            for (Workout_Set__c setRow : sets) {
                String exerciseName = setRow.Workout_Exercise__r.Exercise__r.Name;

                if (exerciseName != currentExercise) {
                    if (currentExercise != '') {
                        preview += '\n';
                    }
                    preview += exerciseName + '\n';
                    currentExercise = exerciseName;
                }

                preview += String.valueOf(setRow.Weight__c) + ' x ' + String.valueOf(setRow.Reps__c) + '\n';
            }

            res.previewText = preview;
            responses.add(res);
        }

        return responses;
    }
}