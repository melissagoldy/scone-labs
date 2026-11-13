
# Scone Labs Wellness Platform

A Salesforce portfolio project combining workout tracking, walking and step tracking, recipe management, nutrition analysis, meal planning, automation, Lightning Web Components, Apex, Flow, and Agentforce.

Because wellness data deserves better than fourteen browser tabs and a spreadsheet named `FINAL_final_v3.xlsx`.

## Project Overview

Scone Labs is a custom Salesforce wellness platform designed to organize personal fitness, walking, and nutrition data in one connected system.

The platform supports or is being developed to support:

- Workout templates, sessions, exercises, and sets
- Recipe ingredients and calculated nutrition
- Meal and meal-item tracking
- Walking activity, daily steps, goals, and routes
- Progressive Walking and Fitness Hub components
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
- Track daily walking activity and steps as development progresses
- Monitor walking goals and routes as development progresses
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

Additional development includes workout duration fields, exercise timing, rest periods, repetition ranges, and related permission-set updates.

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

Meal Items can reference a Recipe or represent a manually entered food item.

Planned enhancements will calculate and roll up calories, protein, carbohydrates, fat, and fiber to the parent Meal.

Development also includes improvements to Meal and Meal Item page layouts and related lists.

### Walking and Step Tracking

The walking data model under development includes:

- `Walking_Day__c`
- `Walking_Goal__c`
- `Walking_Route__c`

The walking implementation includes metadata for:

- Daily step counts
- Walking distance and duration
- Walking dates and activity records
- Step and mileage goals
- Walking routes
- Activity notes
- Comfort, fatigue, recovery, and other walking feedback
- Data validation and record relationships

The walking development snapshot also includes:

- `progressiveWalking` Lightning Web Component
- `walkingMath.js` JavaScript utility
- `WalkingController` Apex controller
- `WalkingControllerTest` Apex test class
- `Scone_Walking_User` permission set

The walking components and metadata are preserved in `walking-org-review/` for continued development.

These files have been committed to GitHub but have not yet been verified as fully integrated, tested, or deployed within the standard Salesforce DX application structure.

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

#### Meal Nutrition Automation

Development includes the `Calculate_Meal_Item_Nutrition` Flow.

The goal is to support nutrition calculations for Meal Items and improve the accuracy of recorded meal totals.

This functionality remains in progress.

### Apex

The project includes Apex services for:

- Recipe ingredient retrieval
- Recipe nutrition calculation
- Workout preview generation
- Saving workout exercise sets
- Recipe ingredient automation

Walking development also includes:

- `WalkingController`
- `WalkingControllerTest`

The walking Apex implementation remains subject to integration and testing.

### Lightning Web Components

The project includes custom Lightning Web Components for:

- Displaying recipe ingredients
- Presenting recipe nutrition information
- Fitness Hub user interface
- Progressive Walking and step tracking (in development)

The walking development snapshot includes:

- `fitnessHub`
- `progressiveWalking`
- `walkingMath.js`

Jest test files are included for Lightning Web Components within the project. Additional walking component testing remains in progress.

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
- Permission sets
- Validation rules
- Salesforce page layouts and Lightning record pages

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

### Completed or Preserved in Source Control

- Custom workout and recipe data models
- Apex recipe and workout services
- Recipe Lightning Web Components
- Agentforce workout insight action
- Agentforce recipe recommendation action
- Grounded Agentforce responses
- Meal and Meal Item base objects
- Workout duration and exercise configuration metadata
- Scone Labs custom tabs and Lightning page metadata
- Selected custom object page layouts
- Walking and step-tracking development snapshot
- Salesforce DX source-control setup
- GitHub repository integration
- Development notes and checkpoints

### In Progress

- Meal nutrition totals
- Meal Item calculation automation
- Meal and Meal Item page-layout improvements
- Realistic sample Meal records
- Detailed workout summaries containing exercises and sets
- Progressive Walking component integration
- Daily step logging and walking-goal functionality
- Walking Apex controller and test validation
- Fitness Hub integration with walking features
- Additional automated tests
- Portfolio screenshots and demonstration materials
- Retrieval and review of remaining application metadata in source control

## Planned Enhancements

1. Add roll-up summary fields for Meal nutrition totals.
2. Build record-triggered automation for recipe-based Meal Items.
3. Improve Meal and Meal Item page layouts.
4. Extend workout insights to include exercises and individual sets.
5. Add additional Agentforce actions for meal and nutrition analysis.
6. Expand Apex and Flow test coverage.
7. Add architecture diagrams, screenshots, and a recorded demonstration.
8. Integrate the Progressive Walking component into Fitness Hub.
9. Validate walking records, goals, routes, and step calculations.
10. Complete walking component testing and deployment preparation.
11. Expand the wellness experience to include walking progress alongside workout and nutrition information.

## Repository Structure

```text
scone-labs/
|
|-- force-app/
|   |-- main/
|       |-- default/
|           |-- classes/        Apex services and controllers
|           |-- flows/          Salesforce Flows
|           |-- lwc/            Lightning Web Components
|           |-- objects/        Custom objects and fields
|           |-- layouts/        Salesforce page layouts
|           |-- flexipages/     Lightning pages
|           |-- permissionsets/ Permission sets
|           |-- tabs/           Custom object tabs
|           |-- triggers/       Apex triggers
|
|-- walking-org-review/         Preserved walking development snapshot
|   |-- classes/                Walking Apex controller and tests
|   |-- lwc/                    Fitness Hub and Progressive Walking
|   |-- objects/                Walking objects, fields, validation rules
|   |-- permissionsets/         Walking permissions
|
|-- docs/
|   |-- fitness-development-notes.md
|
|-- README.md
```

### Development Snapshots

The `walking-org-review/` directory contains a preserved development snapshot of walking-related Apex, Lightning Web Components, custom objects, fields, validation rules, and permissions.

This directory is maintained as a reference while walking features are integrated into the standard Salesforce DX project structure.

The snapshot is not intended to be deployed directly as part of the main `force-app` source directory.

The `docs/fitness-development-notes.md` file contains additional development notes and checkpoints.

Other local review packages and backup archives may exist outside Git source control.

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

**Note:** Deployment commands target the main Salesforce DX source directory. Walking development files stored in `walking-org-review/` require integration into the appropriate Salesforce metadata directories before deployment.

## Author

**MG**

Salesforce Administrator and System Analyst building practical Salesforce solutions with automation, custom development, data modeling, and Agentforce.

Occasionally supervised by a highly classified 🐕.
