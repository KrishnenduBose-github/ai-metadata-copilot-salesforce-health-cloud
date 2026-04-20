# Metadata-Aware Org Navigator & Impact Analyzer

## Recommended Build Order
1. Create the custom objects in the sandbox.
2. Add the shared Tooling API client.
3. Add the metadata extraction service.
4. Add the indexing service that writes to custom objects.
5. Add the search service.
6. Add the impact analysis service.
7. Add the Lightning Web Component and Apex controller.
8. Add tests and deploy.

## Data Model

### 1. Metadata_Item__c
Stores one metadata asset per record.

Suggested fields:
- `Name` (standard): user-friendly label
- `Metadata_Key__c` (Text 255, External ID, Unique): stable key like `ApexClass:MyClass`
- `Metadata_Type__c` (Picklist): `ApexClass`, `Flow`, `CustomField`
- `Api_Name__c` (Text 255): API name of the metadata item
- `Developer_Name__c` (Text 255): developer name when available
- `Object_API_Name__c` (Text 255): parent object for fields
- `Field_API_Name__c` (Text 255): field API name for custom fields
- `Source_Record_Id__c` (Text 50): source metadata id from Tooling API
- `Namespace_Prefix__c` (Text 80): namespace if present
- `Status__c` (Picklist): `Active`, `Inactive`
- `Last_Indexed_On__c` (Date/Time): when this item was last refreshed
- `Definition_Snippet__c` (Long Text Area): optional trimmed source or definition
- `Search_Text__c` (Long Text Area): denormalized text to support simple SOSL searches

### 2. Metadata_Usage__c
Stores one dependency or usage relationship per record.

Suggested fields:
- `Name` (Auto Number or standard text): relationship label
- `Usage_Key__c` (Text 255, External ID, Unique): stable key like `ApexClass:MyClass->Field:Account.Industry`
- `Source_Metadata__c` (Lookup to `Metadata_Item__c`)
- `Target_Metadata__c` (Lookup to `Metadata_Item__c`)
- `Source_Key__c` (Text 255): source metadata key
- `Target_Key__c` (Text 255): target metadata key
- `Usage_Type__c` (Picklist): `UsesField`, `UsesObject`, `InvokesFlow`, `ReferencesApex`
- `Source_Type__c` (Text 100): source metadata type
- `Target_Type__c` (Text 100): target metadata type
- `Match_Text__c` (Text 255): token that matched during parsing
- `Context_Snippet__c` (Long Text Area): short snippet showing where usage was found
- `Last_Analyzed_On__c` (Date/Time): last refresh time

### 3. Impact_Assessment__c
Stores search requests and simple summaries.

Suggested fields:
- `Name` (Auto Number or standard text)
- `Query_Text__c` (Text 255): what the user searched for
- `Query_Type__c` (Picklist): `FieldUsage`, `ObjectUsage`
- `Summary__c` (Long Text Area): readable impact summary
- `Impact_Level__c` (Picklist): `Low`, `Medium`, `High`
- `Match_Count__c` (Number 18,0): number of usage rows found
- `Run_On__c` (Date/Time): when the summary was generated

## Apex Class Breakdown
- `MetadataToolingApiClient`
  Reusable Tooling API callout helper.
- `MetadataExtractionService`
  Queries Apex Classes, Flows, and Custom Fields from Tooling API.
- `MetadataIndexerService`
  Upserts `Metadata_Item__c` records and writes searchable text.
- `MetadataUsageAnalyzerService`
  Scans extracted metadata text and creates `Metadata_Usage__c` records.
- `MetadataSearchService`
  Runs field usage and object usage queries with SOQL/SOSL.
- `MetadataImpactAnalysisService`
  Turns usage rows into a simple human-readable impact summary.
- `MetadataNavigatorController`
  `@AuraEnabled` methods for the LWC.
- `MetadataTestDataFactory`
  Shared helpers for test setup.

## First Class To Create
Create `MetadataToolingApiClient.cls` first.

Why this comes first:
- Every extractor needs one place to call the Tooling API.
- It keeps HTTP logic out of your business classes.
- It is easy to mock and test later.
