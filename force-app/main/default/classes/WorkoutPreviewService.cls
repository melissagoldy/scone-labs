global with sharing class WorkoutPreviewService {

    global class Request {
        @InvocableVariable(required=true)
        public Id workoutTemplateId;
        @InvocableVariable
        public Id exerciseId;
        @InvocableVariable
        public Id currentSessionId;
        @InvocableVariable
        public Id currentWorkoutExerciseId;
    }

    global class Response {
        @InvocableVariable
        public String previewText;
        @InvocableVariable
        public String workoutDisplay;
    }

    @InvocableMethod(
        label='Get Workout Preview'
        description='Returns formatted last workout preview text for a selected workout template.'
    )
    global static List<Response> getWorkoutPreview(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            if (req.exerciseId != null) {
                Date cutoff = Date.today();
                if (req.currentSessionId != null) {
                    List<Workout_Session__c> current = [SELECT Workout_Date__c FROM Workout_Session__c WHERE Id = :req.currentSessionId LIMIT 1];
                    if (!current.isEmpty() && current[0].Workout_Date__c != null) cutoff = current[0].Workout_Date__c;
                }
                List<Workout_Exercise__c> previous = [
                    SELECT Id, Workout_Session__r.Workout_Date__c
                    FROM Workout_Exercise__c
                    WHERE Exercise__c = :req.exerciseId
                    AND Workout_Session__c != :req.currentSessionId
                    AND Workout_Session__r.OwnerId = :UserInfo.getUserId()
                    AND Workout_Session__r.Workout_Status__c = 'Completed'
                    AND Workout_Session__r.Workout_Date__c <= :cutoff
                    AND Id IN (SELECT Workout_Exercise__c FROM Workout_Set__c WHERE Reps__c > 0)
                    ORDER BY Workout_Session__r.Workout_Date__c DESC, CreatedDate DESC
                    LIMIT 1
                ];
                res.previewText = 'No previous completed sets for this exercise yet.';
                if (!previous.isEmpty()) {
                    res.previewText = 'Last performed: ' + String.valueOf(previous[0].Workout_Session__r.Workout_Date__c);
                    for (Workout_Set__c priorSet : [SELECT Set_Number__c, Weight__c, Reps__c FROM Workout_Set__c WHERE Workout_Exercise__c = :previous[0].Id AND Reps__c > 0 ORDER BY Set_Number__c]) {
                        res.previewText += '\nSet ' + String.valueOf(priorSet.Set_Number__c) + ': ' + (priorSet.Weight__c == null ? 'Unspecified weight' : String.valueOf(priorSet.Weight__c) + ' lb') + ' x ' + String.valueOf(priorSet.Reps__c) + ' reps';
                    }
                }

                List<Workout_Exercise__c> lineup = [SELECT Id, Exercise__c, Exercise_Order__c, Exercise__r.Name, Workout_Session__r.Workout_Template__r.Name FROM Workout_Exercise__c WHERE Workout_Session__c = :req.currentSessionId ORDER BY Exercise_Order__c, CreatedDate, Id];
                Integer position = 0;
                String exerciseName = '';
                for (Integer i = 0; i < lineup.size(); i++) {
                    if ((req.currentWorkoutExerciseId != null && lineup[i].Id == req.currentWorkoutExerciseId) || (req.currentWorkoutExerciseId == null && position == 0 && lineup[i].Exercise__c == req.exerciseId)) {
                        position = i + 1;
                        exerciseName = lineup[i].Exercise__r.Name;
                    }
                }
                String prescription = '';
                if (position > 0) {
                    Decimal currentOrder = lineup[position - 1].Exercise_Order__c;
                    List<Planned_Exercise__c> planned = [SELECT Prescription__c FROM Planned_Exercise__c WHERE Workout_Template__c = :req.workoutTemplateId AND Exercise__c = :req.exerciseId AND Exercise_Order__c = :currentOrder LIMIT 1];
                    if (!planned.isEmpty() && planned[0].Prescription__c != null) prescription = planned[0].Prescription__c;
                }
                String display = '<h2 style="color:#176B68;">Today&#39;s workout</h2>';
                if (!lineup.isEmpty()) display += '<p><strong>' + lineup[0].Workout_Session__r.Workout_Template__r.Name.escapeHtml4() + '</strong> &nbsp; | &nbsp; Exercise ' + position + ' of ' + lineup.size() + ' &nbsp; | &nbsp; ' + (lineup.size() - position) + ' left after this</p>';
                display += '<table style="width:100%;"><tbody>';
                for (Integer i = 0; i < lineup.size(); i++) {
                    if (Math.mod(i, 2) == 0) display += '<tr>';
                    String name = String.valueOf(i + 1) + '. ' + lineup[i].Exercise__r.Name.escapeHtml4();
                    display += '<td style="width:50%;padding:4px 8px;">';
                    if (i + 1 == position) display += '<strong style="color:#176B68;">&#8594; ' + name + ' (current)</strong>';
                    else if (i + 1 < position) display += '<span style="color:#687680;">' + name + ' (earlier)</span>';
                    else display += name;
                    display += '</td>';
                    if (Math.mod(i, 2) == 1) display += '</tr>';
                }
                if (Math.mod(lineup.size(), 2) == 1) display += '<td></td></tr>';
                display += '</tbody></table><hr/><h2 style="color:#176B68;">' + exerciseName.escapeHtml4() + '</h2>' + (String.isBlank(prescription) ? '' : '<p><strong>Today&#39;s target</strong><br/>' + prescription.escapeHtml4() + '</p>') + '<p><strong>Last time</strong><br/>' + res.previewText.escapeHtml4().replace('\n', '<br/>') + '</p><h3 style="color:#176B68;">Today&#39;s sets</h3><p>Enter weight and reps, then select Next to save and continue.</p>';
                res.workoutDisplay = display;
                responses.add(res);
                continue;
            }

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