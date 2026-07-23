import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getIngredients from '@salesforce/apex/RecipeIngredientListController.getIngredients';

export default class RecipeIngredientList extends NavigationMixin(LightningElement) {
    @api recordId;
    ingredients = [];
    error;

    @wire(getIngredients, { recipeId: '$recordId' })
    wiredIngredients({ data, error }) {
        if (data) {
            this.ingredients = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.ingredients = [];
            console.error('Error loading recipe ingredients', error);
        }
    }

    get ingredientCount() {
        return this.ingredients ? this.ingredients.length : 0;
    }

    get hasNoIngredients() {
        return this.ingredients && this.ingredients.length === 0;
    }

    handleOpenIngredient(event) {
        const recordId = event.currentTarget.dataset.id;

        if (!recordId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Recipe_Ingredient__c',
                actionName: 'view'
            }
        });
    }
}