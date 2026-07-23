public with sharing class RecipeNutritionService {

    public static void recalculateRecipe(Id recipeId) {

        Decimal totalCalories = 0;
        Decimal totalProtein = 0;
        Decimal totalCarbs = 0;
        Decimal totalFat = 0;
        Decimal totalFiber = 0;

        List<Recipe_Ingredient__c> ingredients = [
            SELECT
                Grams_Used__c,
                Ingredient__r.Calories_per_100g__c,
                Ingredient__r.Protein_per_100g__c,
                Ingredient__r.Carbs_per_100g__c,
                Ingredient__r.Fat_per_100g__c,
                Ingredient__r.Fiber_per_100g__c
            FROM Recipe_Ingredient__c
            WHERE Recipe__c = :recipeId
        ];

        for (Recipe_Ingredient__c ingredient : ingredients) {
            Decimal grams = ingredient.Grams_Used__c == null ? 0 : ingredient.Grams_Used__c;

            Decimal caloriesPer100g = ingredient.Ingredient__r.Calories_per_100g__c == null ? 0 : ingredient.Ingredient__r.Calories_per_100g__c;
            Decimal proteinPer100g = ingredient.Ingredient__r.Protein_per_100g__c == null ? 0 : ingredient.Ingredient__r.Protein_per_100g__c;
            Decimal carbsPer100g = ingredient.Ingredient__r.Carbs_per_100g__c == null ? 0 : ingredient.Ingredient__r.Carbs_per_100g__c;
            Decimal fatPer100g = ingredient.Ingredient__r.Fat_per_100g__c == null ? 0 : ingredient.Ingredient__r.Fat_per_100g__c;
            Decimal fiberPer100g = ingredient.Ingredient__r.Fiber_per_100g__c == null ? 0 : ingredient.Ingredient__r.Fiber_per_100g__c;

            totalCalories += (grams / 100) * caloriesPer100g;
            totalProtein += (grams / 100) * proteinPer100g;
            totalCarbs += (grams / 100) * carbsPer100g;
            totalFat += (grams / 100) * fatPer100g;
            totalFiber += (grams / 100) * fiberPer100g;
        }

        update new Recipe__c(
            Id = recipeId,
            Total_Calories__c = totalCalories,
            Total_Protein__c = totalProtein,
            Total_Carbs__c = totalCarbs,
            Total_Fat__c = totalFat,
            Total_Fiber__c = totalFiber
        );
    }
}