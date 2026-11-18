import { LightningElement, wire } from 'lwc';
import getCompletedSessions from '@salesforce/apex/WorkoutCalendarController.getCompletedSessions';
import { refreshApex } from '@salesforce/apex';

const YEAR_MONTHS = [
    { year: 2026, month: 10 },
    { year: 2026, month: 11 },
    { year: 2027, month: 0 },
    { year: 2027, month: 1 }
];
const START_UTC = Date.UTC(2026, 10, 16);
const END_UTC = Date.UTC(2027, 1, 7);
const MS_PER_DAY = 86400000;

function isoDate(utc) {
    return new Date(utc).toISOString().slice(0, 10);
}

export default class WorkoutCalendar extends LightningElement {
    weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    monthIndex = 0;
    sessions = [];
    errorMessage;
    wiredResult;
    loading = true;

    connectedCallback() {
        const now = new Date();
        const current = YEAR_MONTHS.findIndex(
            (m) => m.year === now.getFullYear() && m.month === now.getMonth()
        );
        this.monthIndex = current === -1 ? 0 : current;
    }

    @wire(getCompletedSessions)
    wiredSessions(result) {
        this.wiredResult = result;
        this.loading = false;
        if (result.data) {
            this.sessions = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.errorMessage = result.error.body?.message || result.error.message || 'Unable to load workout history.';
        }
    }

    async handleRefresh() {
        if (!this.wiredResult) return;
        this.loading = true;
        try {
            await refreshApex(this.wiredResult);
        } finally {
            this.loading = false;
        }
    }

    previousMonth() {
        if (this.monthIndex > 0) this.monthIndex -= 1;
    }

    nextMonth() {
        if (this.monthIndex < YEAR_MONTHS.length - 1) this.monthIndex += 1;
    }

    get isFirstMonth() { return this.monthIndex === 0; }
    get isLastMonth() { return this.monthIndex === YEAR_MONTHS.length - 1; }
    get monthLabel() {
        const { year, month } = YEAR_MONTHS[this.monthIndex];
        return new Date(Date.UTC(year, month, 1)).toLocaleDateString('en-US', {
            month: 'long', year: 'numeric', timeZone: 'UTC'
        });
    }

    get calendarCells() {
        const { year, month } = YEAR_MONTHS[this.monthIndex];
        const firstDay = new Date(Date.UTC(year, month, 1)).getUTCDay();
        const daysInMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
        const count = Math.ceil((firstDay + daysInMonth) / 7) * 7;
        const sessionsByDate = new Map();
        this.sessions.forEach((session) => {
            const date = session.Workout_Date__c;
            if (!sessionsByDate.has(date)) sessionsByDate.set(date, []);
            sessionsByDate.get(date).push(session.Workout_Template__r?.Name);
        });

        return Array.from({ length: count }, (_, index) => {
            const day = index - firstDay + 1;
            if (day < 1 || day > daysInMonth) {
                return { key: `blank-${index}`, className: 'day blank', isBlank: true };
            }

            const utc = Date.UTC(year, month, day);
            const date = isoDate(utc);
            const delta = Math.floor((utc - START_UTC) / MS_PER_DAY);
            const inProgram = utc >= START_UTC && utc <= END_UTC;
            const weekIndex = Math.floor(delta / 7);
            const dayOfWeek = new Date(utc).getUTCDay();
            const isWorkout = inProgram && [1, 3, 5].includes(dayOfWeek);
            const mondayA = weekIndex % 2 === 0;
            let workout = '';
            if (isWorkout) workout = dayOfWeek === 3 ? (mondayA ? 'B' : 'A') : (mondayA ? 'A' : 'B');
            const optional = isWorkout && dayOfWeek === 5 && weekIndex < 2;
            const completedTemplates = sessionsByDate.get(date) || [];
            const completed = isWorkout && completedTemplates.includes(`12-Week Recomp ${workout}`);
            const otherLogged = completedTemplates.length > 0 && !completed;
            const now = new Date();
            const isToday = day === now.getDate() && month === now.getMonth() && year === now.getFullYear();
            return {
                key: date,
                day,
                date,
                isBlank: false,
                isWorkout,
                workout,
                optional,
                completed,
                otherLogged,
                isToday,
                statusLabel: completed ? 'Completed ✓' : optional ? 'Optional' : 'Planned',
                className: `day${isWorkout ? ' workout workout-' + workout.toLowerCase() : ''}${completed ? ' completed' : ''}${isToday ? ' today' : ''}`
            };
        });
    }

    get completedCount() {
        return this.sessions.filter((s) =>
            ['12-Week Recomp A', '12-Week Recomp B'].includes(s.Workout_Template__r?.Name)
        ).length;
    }
}
