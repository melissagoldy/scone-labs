import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

import CALORIES from '@salesforce/schema/Recipe__c.Calories_Per_Serving__c';
import PROTEIN from '@salesforce/schema/Recipe__c.Protein_Per_Serving__c';
import CARBS from '@salesforce/schema/Recipe__c.Carbs_Per_Serving__c';
import FAT from '@salesforce/schema/Recipe__c.Fat_Per_Serving__c';
import FIBER from '@salesforce/schema/Recipe__c.Fiber_Per_Serving__c';

const FIELDS = [CALORIES, PROTEIN, CARBS, FAT, FIBER];

export default class RecipeNutritionCard extends LightningElement {
    @api recordId;

    calories = 0;
    protein = 0;
    carbs = 0;
    fat = 0;
    fiber = 0;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecipe({ data, error }) {
        if (data) {
            this.calories = data.fields.Calories_Per_Serving__c.value ?? 0;
            this.protein = data.fields.Protein_Per_Serving__c.value ?? 0;
            this.carbs = data.fields.Carbs_Per_Serving__c.value ?? 0;
            this.fat = data.fields.Fat_Per_Serving__c.value ?? 0;
            this.fiber = data.fields.Fiber_Per_Serving__c.value ?? 0;
        }

        if (error) {
            console.error('Error loading recipe nutrition data', error);
        }
    }
}