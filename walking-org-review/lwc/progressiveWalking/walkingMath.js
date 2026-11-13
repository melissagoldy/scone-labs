// Date-only arithmetic uses UTC to avoid daylight-saving shifts.
export function shift(date, days) { const d = new Date(date + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + days); return d.toISOString().slice(0, 10); }
export function goalFor(date, goals) { return goals.find(g => g.Effective_Date__c <= date); }
export function outcome(day, goal) {
    if (!goal) return null;
    const metric = goal.Metric__c === 'Steps' ? 'Steps__c' : 'Miles__c';
    const target = goal.Metric__c === 'Steps' ? goal.Step_Goal__c : goal.Mile_Goal__c;
    return day?.[metric] == null || !target ? false : day[metric] >= target;
}
export function summarize(data, end, metric) {
    const byDate = new Map(data.days.map(d => [d.Activity_Date__c, d]));
    const byGoal = new Map(data.goals.map(g => [g.Id, g]));
    const applicable = (date, day) => day ? byGoal.get(day.Goal__c) : goalFor(date, data.goals);
    const field = metric === 'Steps' ? 'Steps__c' : 'Miles__c';
    const rows = Array.from({ length: 7 }, (_, i) => {
        const date = shift(end, i - 6); const day = byDate.get(date); const goal = applicable(date, day);
        return { date, day, goal, value: day?.[field] ?? null, met: outcome(day, goal) };
    });
    const values = rows.filter(r => r.value != null);
    const average = values.length ? values.reduce((n, r) => n + r.value, 0) / values.length : null;
    const closedEnd = end === data.today ? shift(end, -1) : end;
    const closed = Array.from({ length: 7 }, (_, i) => {
        const date = shift(closedEnd, i - 6), day = byDate.get(date), goal = applicable(date, day);
        return { day, goal, met: outcome(day, goal) };
    });
    const eligible = closed.filter(r => r.goal);
    const met = eligible.filter(r => r.met).length;
    let streak = 0;
    let cursor = end;
    const todayDay = byDate.get(cursor);
    if (end === data.today && outcome(todayDay, applicable(cursor, todayDay)) !== true) cursor = shift(cursor, -1);
    while (cursor >= data.historyStart && streak < 400) {
        const day = byDate.get(cursor);
        if (outcome(day, applicable(cursor, day)) !== true) break;
        streak++; cursor = shift(cursor, -1);
    }
    const baselineRows = Array.from({ length: 7 }, (_, i) => byDate.get(shift(closedEnd, i - 6)));
    const baseline = name => { const days = baselineRows.filter(d => d?.[name] != null); return { count: days.length, average: days.length >= 5 ? days.reduce((n, d) => n + d[name], 0) / days.length : null }; };
    const lastAssessment = data.days.find(d => d.Activity_Date__c <= data.today && d.Activity_Date__c >= shift(data.today, -6));
    const recent = data.days.filter(d => d.Activity_Date__c >= shift(data.today, -7) && d.Activity_Date__c <= data.today);
    const concern = recent.some(d => d.Comfort__c === 'Discomfort' || d.Fatigue__c === 'Excessive' || d.Recovery__c === 'Needs recovery');
    const currentGoal = goalFor(data.today, data.goals);
    const four = lastAssessment && lastAssessment.Goal__c === currentGoal?.Id && lastAssessment.Goal_Comfortable__c && lastAssessment.No_Soreness__c && lastAssessment.Enjoyable__c && lastAssessment.Conversational__c && lastAssessment.Comfort__c === 'Comfortable' && lastAssessment.Fatigue__c === 'Normal' && lastAssessment.Recovery__c === 'Recovered';
    const recorded = closed.filter(r => r.day && r.goal && r.goal.Id === currentGoal?.Id && (r.goal.Metric__c === 'Steps' ? r.day.Steps__c != null : r.day.Miles__c != null)).length;
    return { rows, average, recordedDays: values.length, eligible: eligible.length, met, percent: eligible.length ? Math.round(met / eligible.length * 100) : null, streak, baselineSteps: baseline('Steps__c'), baselineMiles: baseline('Miles__c'), baselineEnd: closedEnd, concern, ready: end === data.today && !concern && four && recorded >= 5 && eligible.length >= 5 && met / eligible.length >= 0.7 };
}