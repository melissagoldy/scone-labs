import { LightningElement, api } from 'lwc';
import getHome from '@salesforce/apex/FitnessHubController.getHome';
import getSession from '@salesforce/apex/FitnessHubController.getSession';
import startWorkout from '@salesforce/apex/FitnessHubController.startWorkout';
import saveExercise from '@salesforce/apex/FitnessHubController.saveExercise';
import saveDraft from '@salesforce/apex/FitnessHubController.saveDraft';
import finishWorkout from '@salesforce/apex/FitnessHubController.finishWorkout';
export default class FitnessHub extends LightningElement {
    @api templateId;
    @api sessionId;
    templates = []; recent = []; unfinished = []; exercises = []; session;
    selectedTemplate; selectedIndex = 0; busy = false; error = ''; notice = ''; dirty = false;
    notes = ''; minutes; remaining = 0; timer; deadline;
    theme = 'sage'; showOlder = false; scrollTarget;
    themeOptions = [
        { label: 'Sage · calm green', value: 'sage' },
        { label: 'Ocean · blue', value: 'ocean' },
        { label: 'Plum · warm purple', value: 'plum' },
        { label: 'Slate · crisp neutral', value: 'slate' }
    ];
    connectedCallback() {
        try { const saved = localStorage.getItem('sconeFitnessTheme'); if (this.themeOptions.some(t => t.value === saved)) this.theme = saved; } catch (e) { /* Theme still works when storage is unavailable. */ }
        this.initialize();
    }
    renderedCallback() {
        if (!this.scrollTarget) return;
        const element = this.template.querySelector(this.scrollTarget);
        this.scrollTarget = null;
        if (element) element.scrollIntoView({ behavior: 'auto', block: 'start' });
    }
    changeTheme(event) {
        const value = event.detail.value;
        if (!this.themeOptions.some(t => t.value === value)) return;
        this.theme = value;
        try { localStorage.setItem('sconeFitnessTheme', value); } catch (e) { /* In-memory selection remains available. */ }
    }
    get visibleUnfinished() { return this.showOlder ? this.unfinished : this.unfinished.slice(0, 3); }
    get hasOlder() { return this.unfinished.length > 3; }
    get olderLabel() { return this.showOlder ? 'Show fewer unfinished workouts' : 'Show older unfinished workouts'; }
    toggleOlder() { this.showOlder = !this.showOlder; }
    disconnectedCallback() { clearInterval(this.timer); }
    @api validate() { const walking = this.template.querySelector('c-progressive-walking')?.validate(); if (walking && !walking.isValid) return walking; return { isValid: !this.dirty, errorMessage: 'Save the exercise before closing this workout.' }; }
    async initialize() {
        this.busy = true;
        try {
            const home = JSON.parse(await getHome());
            this.templates = home.templates.map(t => ({ ...t, description: t.Template_Description__c || 'Your next good workout starts here.' }));
            this.recent = home.sessions.map(s => ({ ...s, title: s.Workout_Template__r?.Name || s.Name, subtitle: `${s.Workout_Date__c} · ${s.Workout_Status__c || 'Unspecified'}` }));
            this.unfinished = home.unfinished.map(s => ({ ...s, title: s.Workout_Template__r?.Name || s.Name, subtitle: `Started ${s.Workout_Date__c}` }));
            if (this.templateId) this.selectedTemplate = this.templates.find(t => t.Id === this.templateId);
            if (this.sessionId) await this.loadSession(this.sessionId);
        } catch (e) { this.showError(e); } finally { this.busy = false; }
    }
    async loadSession(id) {
        const data = JSON.parse(await getSession({ sessionId: id }));
        this.session = data.session;
        this.exercises = data.exercises.map(e => ({ ...e, sets: e.sets.map(s => ({ ...s })), safeVideo: /^https:\/\//i.test(e.Exercise__r.Video_URL__c || '') ? e.Exercise__r.Video_URL__c : null }));
        this.notes = this.session.Workout_Notes__c || '';
        const elapsed = this.session.Elapsed_Seconds__c;
        this.minutes = elapsed != null ? Math.round(elapsed / 60) : this.session.Started_At__c ? Math.max(0, Math.round((Date.now() - new Date(this.session.Started_At__c).getTime()) / 60000)) : null;
        this.selectedIndex = Math.max(0, this.exercises.findIndex(e => e.sets.some(s => !this.isLogged(s, e.Is_Timed__c))));
        this.dirty = false;
        this.scrollTarget = '[data-exercise-anchor]';
    }
    isLogged(s, timed) { return s.Skipped__c || (timed ? s.Duration_Seconds__c > 0 : s.Reps__c > 0); }
    get homeVisible() { return !this.session; }
    get hasUnfinished() { return this.unfinished.length > 0; }
    get hasRecent() { return this.recent.length > 0; }
    get templateSelected() { return Boolean(this.selectedTemplate); }
    get completed() { return this.session?.Workout_Status__c === 'Completed'; }
    get current() { return this.exercises[this.selectedIndex]; }
    get hasCurrent() { return Boolean(this.current); }
    get currentName() { return this.current?.Exercise__r.Name; }
    get formNotes() { return this.current?.Exercise__r.Form_Notes__c; }
    get videoUrl() { return this.current?.safeVideo; }
    get weightBasis() { return this.current?.Weight_Basis__c || 'Legacy weight basis is unspecified. Keep your convention consistent.'; }
    get target() {
        const e = this.current;
        if (!e) return '';
        const minimum = e.Min_Reps__c || e.Target_Reps__c || e.Max_Reps__c;
        const reps = e.Max_Reps__c ? (minimum === e.Max_Reps__c ? `${e.Max_Reps__c} reps` : `${minimum}–${e.Max_Reps__c} reps`) : `${e.Target_Reps__c || 'your prescribed'} reps`;
        return `${e.Target_Sets__c || e.sets.length} sets · ${e.Is_Timed__c ? `${e.Target_Seconds__c || 'target'} seconds` : reps}`;
    }
    get prescription() { return this.current?.Prescription_Snapshot__c; }
    get progressText() { return `Exercise ${this.selectedIndex + 1} of ${this.exercises.length}`; }
    get progressValue() { return this.exercises.length ? Math.round((this.selectedIndex + 1) / this.exercises.length * 100) : 0; }
    get setRows() { return (this.current?.sets || []).map(s => ({ ...s, title: `Set ${s.Set_Number__c}`, disabled: this.busy || s.Skipped__c || this.completed })); }
    get isTimed() { return this.current?.Is_Timed__c; }
    get previousRows() { return (this.current?.previousSets || []).map(s => ({ Id: s.Id, text: `Set ${s.Set_Number__c}: ${s.Weight__c == null ? 'weight unspecified' : s.Weight__c + ' lb'} · ${this.isTimed ? s.Duration_Seconds__c + ' sec' : s.Reps__c + ' reps'}` })); }
    get hasPrevious() { return this.previousRows.length > 0; }
    get previousDate() { return this.current?.previousDate; }
    get bestLabel() { return this.current?.bestWeight == null ? '' : `Heaviest logged set in the history reviewed: ${this.current.bestWeight} lb`; }
    get showSuggestion() { return this.current?.considerIncrease; }
    get historyLimited() { return this.current?.historyLimited; }
    get previousDisabled() { return this.busy || this.selectedIndex === 0; }
    get nextDisabled() { return this.busy || this.selectedIndex === this.exercises.length - 1; }
    get homeDisabled() { return this.busy || this.dirty; }
    get savedLabel() { return this.dirty ? 'Unsaved changes. Save before leaving this screen.' : 'Saved entries are available when you return.'; }
    get restLabel() { return this.remaining > 0 ? `${Math.floor(this.remaining / 60)}:${String(this.remaining % 60).padStart(2, '0')}` : 'Ready when you are'; }
    get completedSets() { return this.exercises.reduce((n,e) => n + e.sets.filter(s => !s.Skipped__c && this.isLogged(s,e.Is_Timed__c)).length,0); }
    get skippedSets() { return this.exercises.reduce((n,e) => n + e.sets.filter(s => s.Skipped__c).length,0); }
    get summaryTitle() { return this.session?.Workout_Template__r?.Name || 'Your workout'; }
    get notesDisabled() { return this.busy || this.completed; }
    chooseTemplate(event) { this.selectedTemplate = this.templates.find(t => t.Id === event.currentTarget.dataset.id); this.error = ''; this.scrollTarget = '[data-selection-anchor]'; }
    walkingSaved() { const result = this.template.querySelector('c-progressive-walking')?.validate(); if (result && !result.isValid) { this.error = result.errorMessage; return false; } return true; }
    async begin() {
        if (!this.walkingSaved()) return;
        this.busy = true; this.error = ''; this.notice = '';
        try { const id = await startWorkout({ templateId: this.selectedTemplate.Id }); await this.loadSession(id); }
        catch (e) { this.showError(e); } finally { this.busy = false; }
    }
    async openSession(event) {
        if (!this.walkingSaved()) return;
        this.busy = true; this.error = ''; this.notice = '';
        try { await this.loadSession(event.currentTarget.dataset.id); }
        catch (e) { this.showError(e); } finally { this.busy = false; }
    }
    changeSet(event) {
        const { id, field } = event.target.dataset;
        const value = field === 'Skipped__c' ? event.target.checked : event.target.value === '' ? null : Number(event.target.value);
        this.updateCurrent({ sets: this.current.sets.map(s => s.Id === id ? { ...s, [field]: value } : s) });
        this.dirty = true; this.notice = '';
    }
    updateCurrent(patch) { this.exercises = this.exercises.map((e,i) => i === this.selectedIndex ? { ...e, ...patch } : e); }
    changeForm(event) { this.updateCurrent({ Form_Confirmed__c: event.target.checked }); this.dirty = true; }
    changeNotes(event) { this.notes = event.target.value; this.dirty = true; }
    changeMinutes(event) { this.minutes = event.target.value === '' ? null : Number(event.target.value); this.dirty = true; }
    copyWeights() {
        const prior = this.current.previousSets;
        this.updateCurrent({ sets: this.current.sets.map(s => ({ ...s, Weight__c: prior.find(p => p.Set_Number__c === s.Set_Number__c)?.Weight__c ?? s.Weight__c })) });
        this.dirty = true; this.notice = 'Previous weights copied. Enter the reps or seconds you actually complete.';
    }
    async persistCurrent() {
        const valid = [...this.template.querySelectorAll('lightning-input')].reduce((ok,input) => { input.reportValidity(); return input.checkValidity() && ok; },true);
        if (!valid) throw new Error('Check the highlighted entries.');
        await saveExercise({ sessionId: this.session.Id, workoutExerciseId: this.current.Id,
            setsJson: JSON.stringify(this.current.sets.map(s => ({ Id:s.Id, Weight__c:s.Weight__c ?? null, Reps__c:s.Reps__c ?? null, Duration_Seconds__c:s.Duration_Seconds__c ?? null, Skipped__c:s.Skipped__c || false }))), formConfirmed: this.current.Form_Confirmed__c || false });
        await saveDraft({ sessionId:this.session.Id, notes:this.notes, elapsedSeconds:this.minutes == null ? null : Math.round(this.minutes * 60) });
        this.dirty = false;
    }
    async save() {
        this.busy = true; this.error = '';
        try { await this.persistCurrent(); this.notice = 'Saved to Salesforce. You can return to this workout later.'; }
        catch(e) { this.showError(e); } finally { this.busy = false; }
    }
    async move(event) {
        const direction = Number(event.currentTarget.dataset.direction);
        this.busy = true; this.error = '';
        try { if (!this.completed) await this.persistCurrent(); this.selectedIndex += direction; this.notice = ''; this.scrollTarget = '[data-exercise-anchor]'; }
        catch(e) { this.showError(e); } finally { this.busy = false; }
    }
    async finish() {
        this.busy = true; this.error = '';
        try {
            await this.persistCurrent();
            await finishWorkout({ sessionId:this.session.Id, notes:this.notes, elapsedSeconds:this.minutes == null ? null : Math.round(this.minutes * 60) });
            clearInterval(this.timer); this.remaining = 0;
            await this.loadSession(this.session.Id); this.notice = 'Workout complete. Your effort counts.';
        } catch(e) { this.showError(e); } finally { this.busy = false; }
    }
    async goHome() {
        if (this.dirty) return;
        clearInterval(this.timer); this.remaining = 0; this.session = null; this.sessionId = null; this.templateId = null; this.selectedTemplate = null; this.exercises = []; this.notice = ''; this.error = ''; await this.initialize();
    }
    startRest() {
        clearInterval(this.timer); this.deadline = Date.now() + (this.current?.Rest_Seconds__c || 90) * 1000;
        const tick = () => { this.remaining = Math.max(0, Math.ceil((this.deadline - Date.now()) / 1000)); if (!this.remaining) { clearInterval(this.timer); this.notice = 'Rest timer finished. Continue when you feel ready.'; } };
        tick(); this.timer = setInterval(tick, 250);
    }
    stopRest() { clearInterval(this.timer); this.remaining = 0; }
    showError(e) { this.error = e.body?.message || e.message || 'Something went wrong. Your saved entries are still in Salesforce.'; }
}