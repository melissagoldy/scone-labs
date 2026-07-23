# Scone Labs Wellness Platform

A Salesforce portfolio project combining workout tracking, recipe management, nutrition analysis, meal planning, automation, Lightning Web Components, Apex, Flow, and Agentforce.

Because wellness data deserves better than fourteen browser tabs and a spreadsheet named `FINAL_final_v3.xlsx`.

## Project Overview

Scone Labs is a custom Salesforce wellness platform designed to organize personal fitness and nutrition data in one connected system.

The platform supports:

- Workout templates, sessions, exercises, and sets
- Recipe ingredients and calculated nutrition
- Meal and meal-item tracking
- Agentforce-powered workout insights
- Agentforce-powered recipe recommendations
- Grounded AI responses based on Salesforce records

This project demonstrates the design of a practical Salesforce application from data model through user experience, automation, custom development, and conversational AI.

## Business Problems Addressed

Wellness information is often scattered across spreadsheets, notes, fitness apps, and recipe applications. Scone Labs brings that information together so users can:

- Review completed workouts and identify patterns
- Track exercises, sets, repetitions, and weights
- Manage recipes and ingredient quantities
- Calculate per-serving nutrition
- Compare recipes using recorded nutrition data
- Record meals and individual meal items
- Ask natural-language questions about Salesforce data

## Agentforce Capabilities

The **Scone Labs Wellness Coach** is an Agentforce agent grounded in Salesforce records and configured actions.

The agent uses Salesforce as its source of truth. No hallucinated workouts, imaginary recipes, or protein counts calculated purely from vibes.

### Workout Insights

The agent invokes the `Review_Recent_Workouts` Flow to retrieve the current user's five most recent completed workout sessions.

It can answer questions such as:

- What was my last workout?
- Summarize my recent workout patterns.
- What were my recorded starting energy levels?
- Which workout template have I used most recently?
- Did I mark these workouts as ones I would repeat?

The agent distinguishes between recorded values and missing information rather than inventing details.

### Recipe Recommendations

The agent invokes the `Review_Recipe_Catalog` Flow to review active recipes and their recorded nutrition.

It can answer questions such as:

- Which recipe has the most protein per serving?
- Recommend the lowest-calorie recipe.
- Which recipes are marked Hall of Fame?
- Compare recipes using their recorded macros.

Recipe statuses such as **Testing**, **Keeper**, and **Hall of Fame** are treated as stored labels. The agent does not invent meanings for those statuses.

## Salesforce Architecture

### Workout Management

The workout data model includes:

- `Workout_Template__c`
- `Workout_Session__c`
- `Workout_Exercise__c`
- `Workout_Set__c`
- `Exercise__c`
- `Planned_Exercise__c`

This structure supports reusable workout templates, completed sessions, ordered exercises, and individual set performance.

### Recipe and Nutrition Management

The recipe data model includes:

- `Recipe__c`
- `Ingredient__c`
- `Recipe_Ingredient__c`

A recipe can contain multiple ingredients with quantities and nutrition values. Apex services and Lightning Web Components support recipe display and nutrition calculations.

### Meal Management

The meal data model includes:

- `Meal__c`
- `Meal_Item__c`

Meal Items can reference a Recipe or represent a manually entered food item. Planned enhancements will calculate and roll up calories, protein, carbohydrates, fat, and fiber to the parent Meal.

## Automation

### Flows

#### `Review_Recent_Workouts`

- Retrieves completed workout sessions for the current user
- Sorts sessions by workout date
- Limits the output to the five most recent records
- Returns a formatted summary for Agentforce

#### `Review_Recipe_Catalog`

- Retrieves eligible recipe records
- Returns recipe status, serving information, and per-serving nutrition
- Provides grounded recipe data to Agentforce

### Apex

The project includes Apex services for:

- Recipe ingredient retrieval
- Recipe nutrition calculation
- Workout preview generation
- Saving workout exercise sets
- Recipe ingredient automation

### Lightning Web Components

The project includes custom Lightning Web Components for:

- Displaying recipe ingredients
- Presenting recipe nutrition information

Jest test files are included for the Lightning Web Components.

## Technologies Demonstrated

- Salesforce Agentforce
- Agentforce Builder and Agent Script
- Salesforce Flow
- Apex
- Apex triggers
- Lightning Web Components
- JavaScript
- HTML and CSS
- Jest
- Salesforce DX
- Salesforce CLI
- Visual Studio Code
- Git and GitHub
- SOQL
- Custom objects and relationships

## Responsible AI Design

The Agentforce implementation follows several grounding and safety principles:

- Recommendations are based only on Salesforce records returned by configured actions.
- Missing values are identified as not recorded.
- The agent does not invent workout sessions, recipes, nutrition values, or record details.
- Recipe status labels are presented without assigning unsupported meanings.
- The wellness coach does not diagnose medical conditions or prescribe treatment.
- Users are directed to appropriate professionals for medical concerns.
- Nutrition values come from stored Salesforce data, not wishful thinking about serving sizes.

## Current Development Status

### Completed

- Custom workout and recipe data models
- Apex recipe and workout services
- Recipe Lightning Web Components
- Agentforce workout insight action
- Agentforce recipe recommendation action
- Grounded Agentforce responses
- Meal and Meal Item base objects
- Salesforce DX source-control setup
- GitHub repository integration

### In Progress

- Meal nutrition totals
- Meal Item calculation automation
- Meal and Meal Item page-layout improvements
- Realistic sample Meal records
- Detailed workout summaries containing exercises and sets
- Additional automated tests
- Portfolio screenshots and demonstration materials
- Retrieval of remaining application metadata into source control

## Planned Enhancements

1. Add roll-up summary fields for Meal nutrition totals.
2. Build record-triggered automation for recipe-based Meal Items.
3. Improve Meal and Meal Item page layouts.
4. Extend workout insights to include exercises and individual sets.
5. Add additional Agentforce actions for meal and nutrition analysis.
6. Expand Apex and Flow test coverage.
7. Add architecture diagrams, screenshots, and a recorded demonstration.

## Repository Structure

```text
force-app/main/default/
├── classes/       Apex services and controllers
├── flows/         Agentforce-ready Salesforce Flows
├── lwc/           Lightning Web Components
├── objects/       Custom object and field metadata
└── triggers/      Apex triggers
```

## Local Development

### Prerequisites

- Git
- Node.js
- Salesforce CLI
- Visual Studio Code
- Salesforce Extension Pack for Visual Studio Code
- Access to a Salesforce development org

### Authenticate an Org

```powershell
sf org login web --alias scone-labs
```

### Set the Default Org

```powershell
sf config set target-org=scone-labs
```

### Validate Metadata

```powershell
sf project deploy start --source-dir force-app --target-org scone-labs --dry-run --test-level NoTestRun --wait 30
```

### Deploy Metadata

```powershell
sf project deploy start --source-dir force-app --target-org scone-labs --test-level NoTestRun --wait 30
```

## Author

**MG**

Salesforce Administrator and System Analyst building practical Salesforce solutions with automation, custom development, data modeling, and Agentforce.

Occasionally supervised by a highly classified 🐕.
