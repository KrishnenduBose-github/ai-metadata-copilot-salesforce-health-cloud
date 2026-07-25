public with sharing class NaturalLanguageResolutionService {
    public AiMetadataCopilotModels.NaturalLanguageInterpretation resolve(
        String userPrompt,
        String intent
    ) {
        AiMetadataCopilotModels.NaturalLanguageInterpretation result =
            new AiMetadataCopilotModels.NaturalLanguageInterpretation();
        result.intent = intent;
        result.alternatives = new List<String>();
        result.resolutionMethod = 'CatalogFallback';
        result.confidence = 0;

        if (String.isBlank(userPrompt)) {
            result.reason = 'Enter a metadata question.';
            return result;
        }

        MetadataNormalizationService normalizer = new MetadataNormalizationService();
        AiMetadataCopilotModels.MetadataSearchRequest normalized =
            normalizer.normalizeSearchRequest(userPrompt);
        Boolean exactCatalogMatch = !String.isBlank(normalized.queryText)
            && hasExactCatalogMatch(normalized.queryText);
        if (!String.isBlank(normalized.queryText)
            && (exactCatalogMatch || looksLikeApiName(normalized.queryText))) {
            result.queryType = normalized.queryType;
            result.targetApiName = normalized.queryText;
            result.confidence = exactCatalogMatch ? 1 : 0.85;
            result.reason = exactCatalogMatch
                ? 'Resolved the exact API name in the refreshed metadata catalog.'
                : 'Extracted the exact API name from your question.';
            return result;
        }

        if ('ObjectUsage' == normalized.queryType && !String.isBlank(normalized.queryText)) {
            result.queryType = normalized.queryType;
            result.targetApiName = normalized.queryText;
            result.confidence = 0.8;
            result.reason = 'Resolved the object name from your question.';
            return result;
        }

        List<Metadata_Item__c> candidates = findCandidates(userPrompt);
        if (candidates.isEmpty()) {
            result.queryType = normalized.queryType;
            result.targetApiName = normalized.queryText;
            result.reason = String.isBlank(normalized.queryText)
                ? 'Could not identify a metadata token in your query. Try an explicit API name like Account.Industry or Patient_Status__c.'
                : 'The API name was not found in the refreshed metadata catalog.';
            return result;
        }

        Metadata_Item__c selected = candidates[0];
        result.queryType = selected.Metadata_Type__c == 'CustomField' ? 'FieldUsage' : 'ObjectUsage';
        result.targetApiName = selected.Api_Name__c;
        result.confidence = candidates.size() == 1 ? 0.9 : 0.55;
        result.isAmbiguous = candidates.size() > 1;
        result.reason = candidates.size() == 1
            ? 'Resolved from the refreshed metadata catalog.'
            : 'More than one indexed metadata item matched this question.';

        for (Metadata_Item__c candidate : candidates) {
            result.alternatives.add(candidate.Api_Name__c);
        }
        return result;
    }

    private static Boolean hasExactCatalogMatch(String apiName) {
        if (String.isBlank(apiName) || !Schema.sObjectType.Metadata_Item__c.isAccessible()) {
            return false;
        }
        return ![
            SELECT Id
            FROM Metadata_Item__c
            WHERE Api_Name__c = :apiName
            LIMIT 1
        ].isEmpty();
    }

    private static Boolean looksLikeApiName(String value) {
        return !String.isBlank(value)
            && (value.contains('.') || value.endsWith('__c') || value.endsWith('__r'));
    }

    private static List<Metadata_Item__c> findCandidates(String prompt) {
        if (!Schema.sObjectType.Metadata_Item__c.isAccessible()) {
            return new List<Metadata_Item__c>();
        }

        String normalizedPrompt = normalize(prompt);
        List<Metadata_Item__c> matches = new List<Metadata_Item__c>();
        for (Metadata_Item__c item : [
            SELECT Api_Name__c, Metadata_Type__c, Object_API_Name__c, Field_API_Name__c, Developer_Name__c
            FROM Metadata_Item__c
            WHERE Metadata_Type__c IN ('CustomField', 'ApexClass', 'Flow')
              AND Api_Name__c != null
            LIMIT 2000
        ]) {
            if (matchesPrompt(normalizedPrompt, item)) {
                matches.add(item);
            }
        }
        return matches;
    }

    private static Boolean matchesPrompt(String normalizedPrompt, Metadata_Item__c item) {
        List<String> terms = new List<String>{
            item.Api_Name__c,
            item.Developer_Name__c,
            item.Object_API_Name__c,
            item.Field_API_Name__c
        };
        for (String term : terms) {
            String normalizedTerm = normalize(term);
            if (!String.isBlank(normalizedTerm) && normalizedPrompt.contains(normalizedTerm)) {
                return true;
            }
        }
        return false;
    }

    private static String normalize(String inputValue) {
        if (String.isBlank(inputValue)) {
            return '';
        }
        return inputValue.toLowerCase()
            .replaceAll('[^a-z0-9]', '');
    }
}
