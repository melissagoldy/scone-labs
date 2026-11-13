public with sharing class WalkingController {
    private static AuraHandledException fail(String message) { AuraHandledException e = new AuraHandledException(message); e.setMessage(message); return e; }
    public class DayInput {
        public Date activityDate; public Decimal steps; public Decimal miles; public Decimal minutes;
        public String notes; public String comfort; public String fatigue; public String recovery; public Id routeId;
        public Boolean enjoyable; public Boolean conversational; public Boolean goalComfortable; public Boolean noSoreness;
    }
    public class GoalInput { public String metric; public Decimal steps; public Decimal miles; public String reason; public Id previousGoalId; public Boolean approved; }
    public class RouteInput { public Id id; public String name; public Decimal miles; public Decimal steps; public String notes; public Boolean active; }
    private static void numberRange(Decimal value, Decimal maximum, Boolean whole, String label) {
        if (value != null && (value < 0 || value > maximum || (whole && value != value.setScale(0)) || (!whole && value != value.setScale(2)))) throw fail('Check '+label+': use a nonnegative value within range'+(whole?' and whole numbers.':' with at most two decimal places.'));
    }
    private static void textLength(String value, Integer maximum) { if(value != null && value.length()>maximum) throw fail('Text is too long. Maximum '+maximum+' characters.'); }
    private static void choice(String value, Set<String> allowed) { if(!allowed.contains(value)) throw fail('Choose a valid comfort, fatigue, and recovery response.'); }
    private static List<Walking_Goal__c> goals() {
        List<Walking_Goal__c> rows = [SELECT Id, OwnerId, Effective_Date__c, Metric__c, Step_Goal__c, Mile_Goal__c, Reason__c, Approved_At__c, Baseline_Steps__c, Baseline_Miles__c, Baseline_End__c, Baseline_Step_Days__c, Baseline_Mile_Days__c FROM Walking_Goal__c WHERE OwnerId=:UserInfo.getUserId() WITH USER_MODE ORDER BY Effective_Date__c DESC, Approved_At__c DESC, CreatedDate DESC, Id DESC LIMIT 2001];
        if(rows.size()>2000) throw fail('Goal history exceeds this panel limit. Use a report to review and archive history before continuing.');
        return rows;
    }
    @AuraEnabled
    public static String getDashboard(Date windowEnd) {
        if(windowEnd==null) windowEnd=Date.today();
        if(windowEnd>Date.today()) throw fail('Choose today or an earlier date.');
        Date startDate=windowEnd.addDays(-399);
        List<Walking_Day__c> days=[SELECT Id, Activity_Date__c, Steps__c, Miles__c, Minutes__c, Notes__c, Comfort__c, Fatigue__c, Recovery__c, Enjoyable__c, Conversational__c, Goal_Comfortable__c, No_Soreness__c, Goal__c, Route__c FROM Walking_Day__c WHERE OwnerId=:UserInfo.getUserId() AND Activity_Date__c>=:startDate AND Activity_Date__c<=:windowEnd WITH USER_MODE ORDER BY Activity_Date__c DESC LIMIT 401];
        List<Walking_Route__c> routes=[SELECT Id, Route_Name__c, Miles__c, Approx_Steps__c, Notes__c, Active__c FROM Walking_Route__c WHERE OwnerId=:UserInfo.getUserId() WITH USER_MODE ORDER BY Route_Name__c LIMIT 501];
        return JSON.serialize(new Map<String,Object>{'today'=>Date.today(),'days'=>days,'goals'=>goals(),'routes'=>routes,'routesLimited'=>routes.size()>500,'windowEnd'=>windowEnd,'historyStart'=>startDate});
    }
    @AuraEnabled
    public static Id saveDay(String inputJson) {
        DayInput x=(DayInput)JSON.deserializeStrict(inputJson,DayInput.class);
        if(x==null || x.activityDate==null || x.activityDate>Date.today()) throw fail('Choose today or an earlier activity date.');
        if(x.steps==null && x.miles==null) throw fail('Record steps or distance. Blank is unknown; zero means no activity.');
        numberRange(x.steps,200000,true,'steps'); numberRange(x.miles,200,false,'miles'); numberRange(x.minutes,1440,true,'minutes'); textLength(x.notes,4000);
        choice(x.comfort,new Set<String>{'Comfortable','Discomfort','Not recorded'}); choice(x.fatigue,new Set<String>{'Normal','Excessive','Not recorded'}); choice(x.recovery,new Set<String>{'Recovered','Needs recovery','Not recorded'});
        if(x.routeId!=null && [SELECT count() FROM Walking_Route__c WHERE Id=:x.routeId AND OwnerId=:UserInfo.getUserId() WITH USER_MODE]==0) throw fail('Choose one of your own routes.');
        String key=UserInfo.getUserId()+':'+String.valueOf(x.activityDate);
        List<Walking_Day__c> existing=[SELECT Id, Goal__c FROM Walking_Day__c WHERE Day_Key__c=:key AND OwnerId=:UserInfo.getUserId() WITH USER_MODE FOR UPDATE];
        Walking_Day__c d;
        if(existing.isEmpty()) {
            Id goalId;
            for(Walking_Goal__c g:goals()) if(g.Effective_Date__c<=x.activityDate) {goalId=g.Id;break;}
            d=new Walking_Day__c(Day_Key__c=key,Activity_Date__c=x.activityDate,Goal__c=goalId);
        } else d=existing[0];
        d.Steps__c=x.steps;d.Miles__c=x.miles;d.Minutes__c=x.minutes;d.Notes__c=x.notes;d.Comfort__c=x.comfort;d.Fatigue__c=x.fatigue;d.Recovery__c=x.recovery;d.Route__c=x.routeId;
        d.Enjoyable__c=x.enjoyable==true;d.Conversational__c=x.conversational==true;d.Goal_Comfortable__c=x.goalComfortable==true;d.No_Soreness__c=x.noSoreness==true;
        try { if(existing.isEmpty()) insert as user d; else update as user d; }
        catch(DmlException e) {throw fail('Unable to save this day. It may have been saved in another tab; reload before trying again. '+e.getDmlMessage(0));}
        return d.Id;
    }
    @AuraEnabled
    public static Id approveGoal(String inputJson) {
        GoalInput x=(GoalInput)JSON.deserializeStrict(inputJson,GoalInput.class);
        if(x==null || x.approved!=true) throw fail('Explicit approval is required for a goal change.');
        if(x.metric!='Steps' && x.metric!='Miles') throw fail('Choose Steps or Miles as the primary goal.');
        numberRange(x.steps,200000,true,'step goal');numberRange(x.miles,200,false,'distance goal');
        if((x.metric=='Steps' && (x.steps==null || x.steps<=0)) || (x.metric=='Miles' && (x.miles==null || x.miles<=0))) throw fail('The primary goal must be greater than zero.');
        if(String.isBlank(x.reason)) throw fail('Record the reason for this goal change.');textLength(x.reason,255);
        List<Walking_Goal__c> history=goals(); Walking_Goal__c prior=history.isEmpty()?null:history[0];
        if(x.previousGoalId!=(prior==null?null:prior.Id)) throw fail('Your goal changed in another tab. Reload before approving.');
        if(prior!=null && prior.Metric__c==x.metric && prior.Step_Goal__c==x.steps && prior.Mile_Goal__c==x.miles) throw fail('Change a goal value or primary metric before saving.');
        Date baselineEnd=Date.today().addDays(-1); Date baselineStart=baselineEnd.addDays(-6);
        List<Walking_Day__c> baseline=[SELECT Steps__c, Miles__c FROM Walking_Day__c WHERE OwnerId=:UserInfo.getUserId() AND Activity_Date__c>=:baselineStart AND Activity_Date__c<=:baselineEnd WITH USER_MODE];
        Decimal steps=0,miles=0;Integer stepDays=0,mileDays=0;
        for(Walking_Day__c d:baseline){if(d.Steps__c!=null){steps+=d.Steps__c;stepDays++;}if(d.Miles__c!=null){miles+=d.Miles__c;mileDays++;}}
        Walking_Goal__c g=new Walking_Goal__c(Effective_Date__c=Date.today(),Metric__c=x.metric,Step_Goal__c=x.steps,Mile_Goal__c=x.miles,Reason__c=x.reason,Approved_At__c=System.now(),Change_Key__c=UserInfo.getUserId()+':'+(prior==null?'initial':String.valueOf(prior.Id)),Baseline_End__c=baselineEnd,Baseline_Step_Days__c=stepDays,Baseline_Mile_Days__c=mileDays,Baseline_Steps__c=stepDays>=5?(steps/stepDays).setScale(2):null,Baseline_Miles__c=mileDays>=5?(miles/mileDays).setScale(2):null);
        try{insert as user g;}catch(DmlException e){throw fail('Unable to approve goal. Reload in case another tab changed it. '+e.getDmlMessage(0));}
        return g.Id;
    }
    @AuraEnabled
    public static Id saveRoute(String inputJson) {
        RouteInput x=(RouteInput)JSON.deserializeStrict(inputJson,RouteInput.class);
        if(x==null || String.isBlank(x.name)) throw fail('Name this route.');textLength(x.name,255);textLength(x.notes,4000);numberRange(x.steps,200000,true,'route steps');numberRange(x.miles,200,false,'route miles');
        if((x.steps==null || x.steps==0) && (x.miles==null || x.miles==0)) throw fail('Record a positive route distance or approximate step count.');
        if(x.id!=null && [SELECT count() FROM Walking_Route__c WHERE Id=:x.id AND OwnerId=:UserInfo.getUserId() WITH USER_MODE]==0) throw fail('This route is unavailable for your user.');
        Walking_Route__c r=new Walking_Route__c(Id=x.id,Route_Name__c=x.name.trim(),Miles__c=x.miles,Approx_Steps__c=x.steps,Notes__c=x.notes,Active__c=x.active==true);
        if(x.id==null) insert as user r; else update as user r;
        return r.Id;
    }
}