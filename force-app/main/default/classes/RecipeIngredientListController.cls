public with sharing class RecipeIngredientListController {
    @AuraEnabled(cacheable=true)
    public static List<RecipeIngredientWrapper> getIngredients(Id recipeId) {
        if (recipeId == null) {
            return new List<RecipeIngredientWrapper>();
        }

        List<Recipe_Ingredient__c> rows = [
            SELECT Id,
                   Ingredient__c,
                   Ingredient__r.Name,
                   Display_Amount__c,
                   Notes__c,
                   Ingredient_Order__c
            FROM Recipe_Ingredient__c
            WHERE Recipe__c = :recipeId
            ORDER BY Ingredient_Order__c ASC, CreatedDate ASC
        ];

        List<RecipeIngredientWrapper> results = new List<RecipeIngredientWrapper>();

        for (Recipe_Ingredient__c row : rows) {
            results.add(new RecipeIngredientWrapper(
                row.Id,
                row.Ingredient__r != null ? row.Ingredient__r.Name : null,
                row.Display_Amount__c,
                row.Notes__c
            ));
        }

        return results;
    }

    public class RecipeIngredientWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String ingredientName;
        @AuraEnabled public String displayAmount;
        @AuraEnabled public String notes;

        public RecipeIngredientWrapper(Id id, String ingredientName, String displayAmount, String notes) {
            this.id = id;
            this.ingredientName = ingredientName;
            this.displayAmount = displayAmount;
            this.notes = notes;
        }
    }
}