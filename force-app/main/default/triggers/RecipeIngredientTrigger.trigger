trigger RecipeIngredientTrigger on Recipe_Ingredient__c (
    before insert,
    before update,
    after insert,
    after update,
    after delete,
    after undelete
) {

    if (Trigger.isBefore) {

        Set<Id> ingredientIds = new Set<Id>();

        for (Recipe_Ingredient__c ri : Trigger.new) {
            if (ri.Ingredient__c != null && ri.Quantity__c != null) {
                ingredientIds.add(ri.Ingredient__c);
            }
        }

        Map<Id, Ingredient__c> ingredientMap = new Map<Id, Ingredient__c>([
            SELECT Id, Grams_Per_Unit__c
            FROM Ingredient__c
            WHERE Id IN :ingredientIds
        ]);

        for (Recipe_Ingredient__c ri : Trigger.new) {

            if (
                ri.Ingredient__c != null &&
                ri.Quantity__c != null &&
                ingredientMap.containsKey(ri.Ingredient__c) &&
                ingredientMap.get(ri.Ingredient__c).Grams_Per_Unit__c != null
            ) {

                ri.Grams_Used__c =
                    (ri.Quantity__c *
                     ingredientMap.get(ri.Ingredient__c).Grams_Per_Unit__c)
                    .setScale(2);
            }
        }
    }

    if (Trigger.isAfter) {

        Set<Id> recipeIds = new Set<Id>();

        if (Trigger.new != null) {
            for (Recipe_Ingredient__c ri : Trigger.new) {
                if (ri.Recipe__c != null) {
                    recipeIds.add(ri.Recipe__c);
                }
            }
        }

        if (Trigger.old != null) {
            for (Recipe_Ingredient__c ri : Trigger.old) {
                if (ri.Recipe__c != null) {
                    recipeIds.add(ri.Recipe__c);
                }
            }
        }

        for (Id recipeId : recipeIds) {
            RecipeNutritionService.recalculateRecipe(recipeId);
        }
    }
}