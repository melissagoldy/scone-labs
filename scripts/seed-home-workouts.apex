// Explicit data step. Updates only the four named routines, reuses exact exercise names.
// Rerunnable by template+order. Any duplicate ambiguity aborts the whole transaction.
List<Object> specs=(List<Object>)JSON.deserializeUntyped('[["Upper Body",[["Dumbbell Chest Press",10,12],["One-Arm Dumbbell Row",10,12],["Seated Dumbbell Shoulder Press",10,12],["Dumbbell Lateral Raise",12,12],["Dumbbell Curl",10,12],["Seated Overhead Triceps Extension",10,12]]],["Lower Body",[["Sit-to-Stand",10,12],["Dumbbell Romanian Deadlift (RDL)",10,10],["Glute Bridge",12,12],["Standing Calf Raise",15,15],["Side-Lying Leg Raise",12,12]]],["Core",[["Dead Bug",8,8],["Bird Dog",8,8],["Standing Pallof Press",10,10],["Heel Slide",10,10],["Standing March",20,20]]],["Full Body",[["Goblet Squat to Bench",10,10],["Dumbbell Chest Press",10,10],["One-Arm Dumbbell Row",10,10],["Glute Bridge",12,12],["Farmer Carry",0,0]]]]');
Set<String> routineNames=new Set<String>{'Upper Body','Lower Body','Core','Full Body'};
Map<String,Workout_Template__c> templates=new Map<String,Workout_Template__c>();
for(Workout_Template__c t:[SELECT Id,Name FROM Workout_Template__c WHERE Name IN :routineNames]){System.assert(!templates.containsKey(t.Name),'Duplicate template: '+t.Name);templates.put(t.Name,t);}
List<Workout_Template__c> newTemplates=new List<Workout_Template__c>();
for(String name:routineNames)if(!templates.containsKey(name))newTemplates.add(new Workout_Template__c(Name=name,Template_Description__c='Home workout. Use comfortable technique, recover as needed, and progress reps before weight. Three sets are targets, not a requirement to push through discomfort.'));
insert newTemplates;for(Workout_Template__c t:newTemplates)templates.put(t.Name,t);
Set<String> names=new Set<String>();for(Object raw:specs)for(Object entry:(List<Object>)((List<Object>)raw)[1])names.add((String)((List<Object>)entry)[0]);
Map<String,Exercise__c> exercises=new Map<String,Exercise__c>();
for(Exercise__c e:[SELECT Id,Name FROM Exercise__c WHERE Name IN :names]){System.assert(!exercises.containsKey(e.Name),'Duplicate exercise: '+e.Name);exercises.put(e.Name,e);}
List<Exercise__c> additions=new List<Exercise__c>();
for(String name:names)if(!exercises.containsKey(name))additions.add(new Exercise__c(Name=name,Equipment_Required__c=name=='Standing Pallof Press'?'Resistance Bands':'Bodyweight',Exercise_Category__c=new Set<String>{'Dead Bug','Bird Dog','Standing Pallof Press','Heel Slide','Standing March'}.contains(name)?'Core':'Lower Body'));
insert additions;for(Exercise__c e:additions)exercises.put(e.Name,e);
Set<Id> templateIds=new Set<Id>();for(Workout_Template__c t:templates.values())templateIds.add(t.Id);
Map<String,Planned_Exercise__c> existing=new Map<String,Planned_Exercise__c>();
for(Planned_Exercise__c p:[SELECT Id,Workout_Template__c,Exercise_Order__c FROM Planned_Exercise__c WHERE Workout_Template__c IN :templateIds]){String key=p.Workout_Template__c+':'+String.valueOf(p.Exercise_Order__c.intValue());System.assert(!existing.containsKey(key),'Duplicate planned exercise position: '+key);existing.put(key,p);}
List<Planned_Exercise__c> plans=new List<Planned_Exercise__c>();
for(Object raw:specs){List<Object> spec=(List<Object>)raw;Id templateId=templates.get((String)spec[0]).Id;Integer order=0;
 for(Object entry:(List<Object>)spec[1]){List<Object> row=(List<Object>)entry;String name=(String)row[0];order++;String key=templateId+':'+order;
 Planned_Exercise__c p=existing.containsKey(key)?existing.get(key):new Planned_Exercise__c(Workout_Template__c=templateId,Exercise_Order__c=order);
 p.Exercise__c=exercises.get(name).Id;p.Target_Sets__c=3;p.Is_Timed__c=name=='Farmer Carry';p.Min_Reps__c=p.Is_Timed__c?null:Decimal.valueOf(String.valueOf(row[1]));p.Max_Reps__c=p.Is_Timed__c?null:Decimal.valueOf(String.valueOf(row[2]));p.Enter_the_planned_number_of_sets_for_thi__c=p.Min_Reps__c;p.Target_Seconds__c=p.Is_Timed__c?30:null;p.Rest_Seconds__c=90;
 Boolean weighted=new Set<String>{'Dumbbell Chest Press','One-Arm Dumbbell Row','Seated Dumbbell Shoulder Press','Dumbbell Lateral Raise','Dumbbell Curl','Seated Overhead Triceps Extension','Dumbbell Romanian Deadlift (RDL)','Farmer Carry'}.contains(name);
 p.Weight_Basis__c=weighted?'Per dumbbell':name=='Goblet Squat to Bench'?'Single held weight':name=='Standing Pallof Press'?'Band resistance; use notes':'Bodyweight; added weight only';
 p.Prescription__c=name=='Farmer Carry'?'3 carries of 30 seconds. Weight is per hand.':name=='Standing March'?'3 sets of 20 alternating marches total.':(new Set<String>{'One-Arm Dumbbell Row','Side-Lying Leg Raise','Dead Bug','Bird Dog','Standing Pallof Press'}.contains(name)?'Reps are per side. Use the same convention each time.':'Use controlled repetitions and a comfortable range of motion.');plans.add(p);
 }}
upsert plans;
System.debug('Fitness routines ready. Existing Foundation and Strength A/B/C routines were not changed.');
