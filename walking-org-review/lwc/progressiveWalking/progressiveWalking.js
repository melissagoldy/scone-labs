import { LightningElement, api } from 'lwc';
import LightningConfirm from 'lightning/confirm';
import getDashboard from '@salesforce/apex/WalkingController.getDashboard';
import saveDay from '@salesforce/apex/WalkingController.saveDay';
import approveGoal from '@salesforce/apex/WalkingController.approveGoal';
import saveRoute from '@salesforce/apex/WalkingController.saveRoute';
import { shift, summarize } from './walkingMath';
export default class ProgressiveWalking extends LightningElement {
    data; busy = false; error = ''; notice = ''; windowEnd; metric = 'Steps'; day = {}; goal = {}; route = {}; dayDirty = false; routeDirty = false; goalDirty = false;
    metrics = [{label:'Steps',value:'Steps'},{label:'Miles',value:'Miles'}];
    comforts = ['Not recorded','Comfortable','Discomfort'].map(value => ({label:value,value}));
    fatigues = ['Not recorded','Normal','Excessive'].map(value => ({label:value,value}));
    recoveries = ['Not recorded','Recovered','Needs recovery'].map(value => ({label:value,value}));
    @api validate() { return { isValid: !(this.dayDirty || this.goalDirty || this.routeDirty), errorMessage: 'Save walking changes before starting a workout or leaving this screen.' }; }
    async connectedCallback() { await this.load(); }
    async load() {
        this.busy = true; this.error = '';
        try {
            this.data = JSON.parse(await getDashboard({windowEnd:this.windowEnd || null}));
            this.windowEnd = this.data.windowEnd; this.metric = this.currentGoal?.Metric__c || 'Steps';
            this.loadDay(this.day.activityDate || this.data.today); this.resetGoal(); this.resetRoute();
        } catch(e) { this.showError(e); } finally { this.busy = false; }
    }
    get loaded() { return Boolean(this.data); }
    get currentGoal() { return this.data?.goals.find(g => g.Effective_Date__c <= this.data.today); }
    get stats() { return summarize(this.data, this.windowEnd, this.metric); }
    get baselineText() { const s=this.stats;return `Measured baseline, 7 days ending ${s.baselineEnd}: ${s.baselineSteps.average == null ? `steps pending (${s.baselineSteps.count}/5 days)` : Math.round(s.baselineSteps.average).toLocaleString()+' steps/day'} · ${s.baselineMiles.average == null ? `distance pending (${s.baselineMiles.count}/5 days)` : s.baselineMiles.average.toFixed(2)+' miles/day'}.`; }
    get goalText() { const g=this.currentGoal;return g ? `${g.Step_Goal__c == null?'No step reference':g.Step_Goal__c.toLocaleString()+' steps'} · ${g.Mile_Goal__c == null?'No distance reference':g.Mile_Goal__c+' miles'} · primary: ${g.Metric__c}` : 'No approved goal yet. Suggested starting values are available below.'; }
    get averageText() { const s=this.stats;return s.average==null?'No recorded values':`${this.metric==='Steps'?Math.round(s.average).toLocaleString():s.average.toFixed(2)} ${this.metric.toLowerCase()}/day across ${s.recordedDays} recorded days`; }
    get achievementText() { const s=this.stats;return s.percent==null?'No goal to evaluate in the last 7 completed days':`${s.met}/${s.eligible} eligible calendar days met their saved primary goal (${s.percent}%). Missing activity counts as not met.`; }
    get streakText() { return `${this.stats.streak}${this.stats.streak===400?'+':''} consecutive goal days (up to 400 days reviewed)`; }
    get chartRows() {
        const rows=this.stats.rows, max=Math.max(1,...rows.map(r=>r.value||0));
        return rows.map(r=>({key:r.date,label:r.date.slice(5),value:r.value==null?'Not recorded':String(r.value),style:`width:${r.value==null?0:Math.max(0,r.value/max*100)}%`,status:r.met===null?'No goal':r.met?'Goal met':'Goal not met / not recorded'}));
    }
    get progressText() {
        const date=this.day.activityDate, d=this.data.days.find(r=>r.Activity_Date__c===date), g=d?this.data.goals.find(r=>r.Id===d.Goal__c):this.data.goals.find(r=>r.Effective_Date__c<=date);
        if(!g)return 'No goal assigned to this day. Goals apply to newly recorded days; existing daily goal references stay unchanged.';
        const value=g.Metric__c==='Steps'?d?.Steps__c:d?.Miles__c, target=g.Metric__c==='Steps'?g.Step_Goal__c:g.Mile_Goal__c;
        return value==null?`No saved ${g.Metric__c.toLowerCase()} yet for ${date}`:`${value} / ${target} ${g.Metric__c.toLowerCase()} (${Math.round(value/target*100)}%). Saved values, compared with this day's original goal.`;
    }
    get progressValue() { const d=this.data.days.find(r=>r.Activity_Date__c===this.day.activityDate),g=this.data.goals.find(r=>r.Id===d?.Goal__c);if(!g)return 0;const v=g.Metric__c==='Steps'?d.Steps__c:d.Miles__c,t=g.Metric__c==='Steps'?g.Step_Goal__c:g.Mile_Goal__c;return Math.min(100,Math.max(0,(v||0)/t*100)); }
    get recommendation() {
        if(this.stats.concern)return 'Hold or reduce the goal while discomfort, excessive fatigue, or recovery needs are recorded. A reduction can be entered under Edit goal.';
        if(this.stats.ready)return this.currentGoal?.Metric__c==='Miles'?'Optional next step: consider adding 0.25–0.5 miles/day. Review the goal below and approve only if you want to change it.':'Optional next step: consider adding 1,000–3,000 steps/day. Review the goal below and approve only if you want to change it.';
        return 'Keep the current goal while building a comfortable record. A progression suggestion needs at least 5 recorded days, 70% of eligible completed days meeting the goal, and all four readiness criteria confirmed. No goal changes automatically.';
    }
    get canSuggest() { return this.stats.ready && Boolean(this.currentGoal); }
    get routes() { return this.data.routes.filter(r=>r.Active__c).slice(0,500).map(r=>({...r,label:`${r.Route_Name__c} · ${r.Miles__c??'?'} mi · ~${r.Approx_Steps__c??'?'} steps`})); }
    get routeOptions() { return [{label:'No route',value:''},...this.data.routes.slice(0,500).map(r=>({label:r.Route_Name__c,value:r.Id}))]; }
    get goalHistory() { return this.data.goals.map(g=>({...g,line:`${g.Effective_Date__c} · ${g.Metric__c} primary · ${g.Step_Goal__c??'—'} steps / ${g.Mile_Goal__c??'—'} mi`,baseline:`Baseline snapshot: ${g.Baseline_Steps__c??'pending'} steps (${g.Baseline_Step_Days__c} days), ${g.Baseline_Miles__c??'pending'} mi (${g.Baseline_Mile_Days__c} days), window ending ${g.Baseline_End__c}`})); }
    get routesLimited() { return this.data.routesLimited; }
    get dayHistory() { return this.data.days.filter(d=>d.Activity_Date__c>=shift(this.windowEnd,-6)).map(d=>({...d,label:`${d.Activity_Date__c} · ${d.Steps__c??'not recorded'} steps · ${d.Miles__c??'not recorded'} mi · ${d.Minutes__c??'not recorded'} minutes`})); }
    resetGoal() { const g=this.currentGoal;this.goal={metric:g?.Metric__c||'Steps',steps:g?(g.Step_Goal__c??null):7500,miles:g?(g.Mile_Goal__c??null):2.7,reason:'',previousGoalId:g?.Id||null};this.goalDirty=false; }
    resetRoute() {this.route={id:null,name:'',miles:null,steps:null,notes:'',active:true};this.routeDirty=false;}
    loadDay(date) {const d=this.data.days.find(r=>r.Activity_Date__c===date);this.day={activityDate:date,steps:d?.Steps__c??null,miles:d?.Miles__c??null,minutes:d?.Minutes__c??null,notes:d?.Notes__c||'',comfort:d?.Comfort__c||'Not recorded',fatigue:d?.Fatigue__c||'Not recorded',recovery:d?.Recovery__c||'Not recorded',routeId:d?.Route__c||null,enjoyable:d?.Enjoyable__c||false,conversational:d?.Conversational__c||false,goalComfortable:d?.Goal_Comfortable__c||false,noSoreness:d?.No_Soreness__c||false};this.dayDirty=false;}
    changeDay(event) {const {field}=event.target.dataset;const value=event.target.type==='checkbox'?event.target.checked:event.detail?.value??event.target.value;this.day={...this.day,[field]:['steps','miles','minutes'].includes(field)?value===''?null:Number(value):value};this.dayDirty=true;this.notice='';}
    async changeDate(event) {const date=event.target.value;if(!date||date>this.data.today)return; if(this.dayDirty && !(await this.confirm('Discard unsaved daily walking changes?')))return;if(date< this.data.historyStart || date>this.windowEnd){if(this.goalDirty||this.routeDirty){this.error='Save goal and route changes before selecting a date outside the loaded window.';return;}this.windowEnd=date;this.day.activityDate=date;await this.load();}else this.loadDay(date);}
    async changeWindow(event) {const date=event.target.value;if(!date||date>this.data.today)return;if((this.dayDirty||this.goalDirty||this.routeDirty)&&!(await this.confirm('Discard unsaved walking changes and change the review window?')))return;this.windowEnd=date;this.day={activityDate:date};await this.load();}
    changeMetric(event) {this.metric=event.detail.value;}
    changeGoal(event) {const field=event.target.dataset.field,value=event.detail?.value??event.target.value;this.goal={...this.goal,[field]:['steps','miles'].includes(field)?value===''?null:Number(value):value};this.goalDirty=true;}
    changeRoute(event) {const field=event.target.dataset.field,value=event.target.type==='checkbox'?event.target.checked:event.detail?.value??event.target.value;this.route={...this.route,[field]:['steps','miles'].includes(field)?value===''?null:Number(value):value};this.routeDirty=true;}
    editRoute(event) {const r=this.data.routes.find(x=>x.Id===event.detail.value);if(this.routeDirty){this.error='Save route changes before choosing another route.';return;}if(!r){this.resetRoute();return;}this.route={id:r.Id,name:r.Route_Name__c,miles:r.Miles__c??null,steps:r.Approx_Steps__c??null,notes:r.Notes__c||'',active:r.Active__c};}
    neighborhood() {if(this.routeDirty){this.error='Save route changes first.';return;}this.route={id:null,name:'Neighborhood loop',miles:0.78,steps:2050,notes:'Historical route estimate. Confirm actual distance and steps.',active:true};this.routeDirty=true;}
    routeShortcut(event) {const r=this.data.routes.find(x=>x.Id===event.currentTarget.dataset.id);this.day={...this.day,routeId:r.Id};this.dayDirty=true;this.notice='Route selected as a reference. Enter your actual daily total; route estimates are not added to your steps or distance.';}
    suggest() {const g=this.currentGoal;this.goal={metric:g.Metric__c,steps:g.Step_Goal__c,miles:g.Mile_Goal__c,reason:'Comfortable progression reviewed',previousGoalId:g.Id};if(g.Metric__c==='Steps')this.goal.steps+=1000;else this.goal.miles=Number((this.goal.miles+0.25).toFixed(2));this.goalDirty=true;const editor=this.template.querySelector('[data-section="goal"]');if(editor)editor.open=true;this.notice='The smallest suggested increase is filled in. Only the primary target changed. Review Edit goal, then approve if you agree.';}
    valid(section) {return [...this.template.querySelectorAll(`[data-section="${section}"] lightning-input, [data-section="${section}"] lightning-combobox, [data-section="${section}"] lightning-textarea`)].reduce((ok,e)=>{e.reportValidity();return e.checkValidity()&&ok;},true);}
    async confirm(message) {return LightningConfirm.open({message,label:'Confirm walking change',variant:'header'});}
    async saveDaily() {if(!this.valid('day'))return;await this.mutate(()=>saveDay({inputJson:JSON.stringify(this.day)}),'Walking day saved.');}
    async saveGoal() {if(!this.valid('goal'))return;const g=this.goal;const payload=JSON.stringify({...g,approved:true});if(!(await this.confirm(`Approve ${g.metric} as your primary goal, with ${g.steps??'no'} steps and ${g.miles??'no'} miles? Only the primary metric is required. Effective today for newly recorded days. Reason: ${g.reason}`)))return;await this.mutate(()=>approveGoal({inputJson:payload}),'Goal approved and added to history.');}
    async saveRouteEntry() {if(!this.valid('route'))return;await this.mutate(()=>saveRoute({inputJson:JSON.stringify(this.route)}),'Route saved.');}
    async mutate(action,message) {if(this.busy)return;this.busy=true;this.error='';try {await action();this.notice=message;const date=this.day.activityDate;const daily={...this.day},goal={...this.goal},route={...this.route};const keepDay=message!=='Walking day saved.'&&this.dayDirty,keepGoal=message!=='Goal approved and added to history.'&&this.goalDirty,keepRoute=message!=='Route saved.'&&this.routeDirty;await this.load();this.loadDay(date);if(keepDay){this.day=daily;this.dayDirty=true;}if(keepGoal){this.goal={...goal,previousGoalId:this.currentGoal?.Id||null};this.goalDirty=true;}if(keepRoute){this.route=route;this.routeDirty=true;}}catch(e){this.showError(e);}finally{this.busy=false;}}
    showError(e) {this.error=e.body?.message||e.message||'Walking data could not be loaded.';}
    get unsavedText() {return this.dayDirty||this.goalDirty||this.routeDirty?'Unsaved walking changes. Save each edited section before leaving the Hub.':'';}
}