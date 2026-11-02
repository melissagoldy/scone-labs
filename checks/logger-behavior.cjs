// Local logic tests with Apex calls stubbed. These do not replace Salesforce tests.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let saved; let draft; let failSave = false; let completed = false;
const source = fs.readFileSync('force-app/main/default/lwc/fitnessHub/fitnessHub.js', 'utf8')
    .replace(/^import .*;\n/gm, '').replace(/@api /g, '').replace('export default class FitnessHub', 'class FitnessHub');
const context = { LightningElement:class {}, console, setInterval, clearInterval,
    saveExercise:async payload => {if(failSave) throw new Error('Network interrupted');saved = payload;},
    saveDraft:async payload => {draft = payload;}, finishWorkout:async () => {completed = true;},
    getHome:async () => '{}',getSession:async () => '{}',startWorkout:async () => 'session' };
vm.createContext(context); vm.runInContext(source+'\nthis.FitnessHub=FitnessHub;',context);
(async()=>{
    const hub=new context.FitnessHub();hub.template={querySelectorAll:()=>[]};hub.session={Id:'s',Workout_Status__c:'Started'};hub.notes='Draft note';hub.minutes=12;
    hub.exercises=[{Id:'e1',Exercise__r:{Name:'Row'},Target_Sets__c:3,sets:[{Id:'a',Set_Number__c:1,Weight__c:10,Reps__c:8},{Id:'b',Set_Number__c:2},{Id:'c',Set_Number__c:3}],previousSets:[{Id:'p',Set_Number__c:1,Weight__c:15}],Is_Timed__c:false},{Id:'e2',Exercise__r:{Name:'Carry'},sets:[{Id:'d'}],Is_Timed__c:true}];
    hub.copyWeights();assert.equal(hub.current.sets[0].Weight__c,15);assert.equal(hub.current.sets[0].Reps__c,8,'Copy must not fabricate performed reps');assert.equal(hub.current.sets[1].Weight__c,undefined);assert.equal(hub.dirty,true);
    await hub.save();assert.equal(hub.dirty,false);assert.equal(JSON.parse(saved.setsJson).length,3);assert.equal(draft.notes,'Draft note');assert.equal(draft.elapsedSeconds,720);
    hub.changeSet({target:{dataset:{id:'b',field:'Skipped__c'},checked:true}});assert.equal(hub.current.sets[1].Skipped__c,true);assert.equal(hub.skippedSets,1);
    hub.changeSet({target:{dataset:{id:'a',field:'Reps__c'},value:''}});assert.equal(hub.current.sets[0].Reps__c,null);
    failSave=true;await hub.move({currentTarget:{dataset:{direction:'1'}}});assert.equal(hub.selectedIndex,0,'Failed save must prevent moving away');assert.equal(hub.dirty,true);assert.match(hub.error,/Network interrupted/);
    await hub.finish();assert.equal(completed,false,'Failed save must prevent completion');
    failSave=false;await hub.move({currentTarget:{dataset:{direction:'1'}}});assert.equal(hub.selectedIndex,1);assert.equal(hub.isTimed,true);
    hub.changeSet({target:{dataset:{id:'d',field:'Duration_Seconds__c'},value:'30'}});assert.equal(hub.current.sets[0].Duration_Seconds__c,30);assert.equal(hub.completedSets,1);
    hub.changeNotes({target:{value:'Keep this note'}});assert.equal(hub.dirty,true);
    hub.disconnectedCallback();console.log('PASS: variable rows, copy weights, explicit skips, null clearing, save/resume draft, failure retention, timed sets.');
})().catch(e=>{console.error(e);process.exitCode=1;});
