@IsTest
private class WalkingControllerTest {
    @TestSetup static void permissions() {
        insert new PermissionSetAssignment(AssigneeId=UserInfo.getUserId(),PermissionSetId=[SELECT Id FROM PermissionSet WHERE Name='Scone_Walking_User'].Id);
        String uniqueValue=UserInfo.getOrganizationId()+String.valueOf(System.now().getTime());
        insert new User(LastName='WalkingOther',Alias='walkoth',Email='walking@example.invalid',Username='walking.'+uniqueValue+'@example.invalid',TimeZoneSidKey='America/New_York',LocaleSidKey='en_US',EmailEncodingKey='UTF-8',LanguageLocaleKey='en_US',ProfileId=UserInfo.getProfileId());
    }
    private static WalkingController.DayInput day(Date d,Decimal steps,Decimal miles) {
        WalkingController.DayInput x=new WalkingController.DayInput();x.activityDate=d;x.steps=steps;x.miles=miles;x.minutes=30;x.comfort='Comfortable';x.fatigue='Normal';x.recovery='Recovered';x.enjoyable=true;x.conversational=true;x.goalComfortable=true;x.noSoreness=true;return x;
    }
    private static WalkingController.GoalInput goal() {
        WalkingController.GoalInput x=new WalkingController.GoalInput();x.metric='Steps';x.steps=7500;x.miles=2.7;x.reason='Initial manual goal';x.approved=true;return x;
    }
    @IsTest static void savesDailyTotalsWithoutDuplicates() { System.runAs(new User(Id=UserInfo.getUserId())) {
        WalkingController.DayInput x=day(Date.today(),6000,2.45);Id first=WalkingController.saveDay(JSON.serialize(x));x.steps=6500;x.miles=null;
        System.assertEquals(first,WalkingController.saveDay(JSON.serialize(x)));System.assertEquals(1,[SELECT count() FROM Walking_Day__c]);
        Walking_Day__c d=[SELECT Steps__c,Miles__c,Goal_Comfortable__c FROM Walking_Day__c WHERE Id=:first];System.assertEquals(6500,d.Steps__c);System.assertEquals(null,d.Miles__c);System.assert(d.Goal_Comfortable__c);
        x.steps=0;WalkingController.saveDay(JSON.serialize(x));System.assertEquals(0,[SELECT Steps__c FROM Walking_Day__c WHERE Id=:first].Steps__c);
    }}
    @IsTest static void rejectsInvalidDayAndRouteValues() { System.runAs(new User(Id=UserInfo.getUserId())) {
        List<WalkingController.DayInput> bad=new List<WalkingController.DayInput>{day(Date.today().addDays(1),1,null),day(Date.today(),null,null),day(Date.today(),-1,null),day(Date.today(),1.5,null),day(Date.today(),1,2.456)};
        WalkingController.DayInput invalid=day(Date.today(),1,null);invalid.comfort='invented';bad.add(invalid);
        invalid=day(Date.today(),1,null);invalid.minutes=1441;bad.add(invalid);
        for(WalkingController.DayInput x:bad){Boolean rejected=false;try{WalkingController.saveDay(JSON.serialize(x));}catch(Exception e){rejected=true;}System.assert(rejected,'Expected invalid daily total to be rejected');}
        WalkingController.RouteInput r=new WalkingController.RouteInput();r.name=' ';r.miles=.78;Boolean rejected=false;try{WalkingController.saveRoute(JSON.serialize(r));}catch(Exception e){rejected=true;}System.assert(rejected);
        r.name='Loop';r.miles=0;r.steps=0;rejected=false;try{WalkingController.saveRoute(JSON.serialize(r));}catch(Exception e){rejected=true;}System.assert(rejected);
    }}
    @IsTest static void goalsRequireApprovalAndPreserveHistory() { System.runAs(new User(Id=UserInfo.getUserId())) {
        WalkingController.GoalInput x=goal();x.approved=false;Boolean rejected=false;try{WalkingController.approveGoal(JSON.serialize(x));}catch(Exception e){rejected=true;}System.assert(rejected);
        x.approved=true;Id initial=WalkingController.approveGoal(JSON.serialize(x));WalkingController.DayInput d=day(Date.today(),8000,2.8);Id dayId=WalkingController.saveDay(JSON.serialize(d));
        x.previousGoalId=initial;x.steps=8500;x.reason='Approved comfortable increase';Id next=WalkingController.approveGoal(JSON.serialize(x));System.assertNotEquals(initial,next);WalkingController.saveDay(JSON.serialize(d));
        System.assertEquals(initial,[SELECT Goal__c FROM Walking_Day__c WHERE Id=:dayId].Goal__c,'A change must not rewrite the original daily comparison');
        rejected=false;try{WalkingController.approveGoal(JSON.serialize(x));}catch(Exception e){rejected=true;}System.assert(rejected,'Stale approval must fail');
        rejected=false;try{update new Walking_Goal__c(Id=initial,Step_Goal__c=9999);}catch(DmlException e){rejected=true;}System.assert(rejected,'Goal rows are append-only');
        x.previousGoalId=next;rejected=false;try{WalkingController.approveGoal(JSON.serialize(x));}catch(Exception e){rejected=true;}System.assert(rejected,'Unchanged goals must fail');
        x.metric='Miles';x.steps=null;x.miles=2.5;x.reason='Distance only, reduce goal';WalkingController.approveGoal(JSON.serialize(x));System.assertEquals(3,[SELECT count() FROM Walking_Goal__c]);
    }}
    @IsTest static void baselineRequiresFiveRecordedDaysPerMetric() { System.runAs(new User(Id=UserInfo.getUserId())) {
        for(Integer i=1;i<=5;i++)WalkingController.saveDay(JSON.serialize(day(Date.today().addDays(-i),6000+i*100,i==5?null:2.4)));
        Id id=WalkingController.approveGoal(JSON.serialize(goal()));Walking_Goal__c g=[SELECT Baseline_Steps__c,Baseline_Miles__c,Baseline_Step_Days__c,Baseline_Mile_Days__c FROM Walking_Goal__c WHERE Id=:id];
        System.assertEquals(6300,g.Baseline_Steps__c);System.assertEquals(null,g.Baseline_Miles__c);System.assertEquals(5,g.Baseline_Step_Days__c);System.assertEquals(4,g.Baseline_Mile_Days__c);
        Map<String,Object> data=(Map<String,Object>)JSON.deserializeUntyped(WalkingController.getDashboard(null));System.assertEquals(5,((List<Object>)data.get('days')).size());
        Boolean rejected=false;try{WalkingController.getDashboard(Date.today().addDays(1));}catch(Exception e){rejected=true;}System.assert(rejected);
    }}
    @IsTest static void routesAreReferencesAndCanBeEdited() { System.runAs(new User(Id=UserInfo.getUserId())) {
        WalkingController.RouteInput r=new WalkingController.RouteInput();r.name='Neighborhood';r.miles=.78;r.steps=2050;r.active=true;r.notes='Estimate';Id routeId=WalkingController.saveRoute(JSON.serialize(r));r.id=routeId;r.name='Neighborhood loop';r.active=false;System.assertEquals(routeId,WalkingController.saveRoute(JSON.serialize(r)));
        WalkingController.DayInput x=day(Date.today(),6500,2.5);x.routeId=routeId;Id id=WalkingController.saveDay(JSON.serialize(x));System.assertEquals(6500,[SELECT Steps__c FROM Walking_Day__c WHERE Id=:id].Steps__c,'Route shortcut must not add estimates');
        Map<String,Object> data=(Map<String,Object>)JSON.deserializeUntyped(WalkingController.getDashboard(null));System.assertEquals(1,((List<Object>)data.get('routes')).size());
    }}
    @IsTest static void rejectsOtherOwnersAndUnapprovedGoals() {
        Id other=[SELECT Id FROM User WHERE Alias='walkoth' AND LastName='WalkingOther' LIMIT 1].Id;
        Walking_Route__c r=new Walking_Route__c(OwnerId=other,Route_Name__c='Private loop',Miles__c=1);insert r;
        Walking_Day__c otherDay=new Walking_Day__c(OwnerId=other,Activity_Date__c=Date.today(),Steps__c=4000,Day_Key__c=other+':'+String.valueOf(Date.today()));insert otherDay;
        System.runAs(new User(Id=UserInfo.getUserId())) {
            WalkingController.RouteInput x=new WalkingController.RouteInput();x.id=r.Id;x.name='Forbidden';x.miles=2;Boolean rejected=false;try{WalkingController.saveRoute(JSON.serialize(x));}catch(Exception e){rejected=true;}System.assert(rejected);
            WalkingController.DayInput d=day(Date.today(),6000,null);d.routeId=r.Id;rejected=false;try{WalkingController.saveDay(JSON.serialize(d));}catch(Exception e){rejected=true;}System.assert(rejected);
            Map<String,Object> data=(Map<String,Object>)JSON.deserializeUntyped(WalkingController.getDashboard(null));System.assertEquals(0,((List<Object>)data.get('days')).size());System.assertEquals(0,((List<Object>)data.get('routes')).size());
            WalkingController.GoalInput g=goal();g.metric='Both';rejected=false;try{WalkingController.approveGoal(JSON.serialize(g));}catch(Exception e){rejected=true;}System.assert(rejected);
            g=goal();g.steps=0;rejected=false;try{WalkingController.approveGoal(JSON.serialize(g));}catch(Exception e){rejected=true;}System.assert(rejected);
            g=goal();g.reason='';rejected=false;try{WalkingController.approveGoal(JSON.serialize(g));}catch(Exception e){rejected=true;}System.assert(rejected);
        }
    }
}