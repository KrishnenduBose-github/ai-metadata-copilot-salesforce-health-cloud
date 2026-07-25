public with sharing class MetadataSearchService {
    /*
     * This service provides simple search methods for field usage and object usage.
     */

    public class SearchResultRow {
        @AuraEnabled public Id usageId;
        @AuraEnabled public String sourceMetadataName;
        @AuraEnabled public String sourceMetadataType;
        @AuraEnabled public String targetKey;
        @AuraEnabled public String usageType;
        @AuraEnabled public String matchText;
        @AuraEnabled public String contextSnippet;
    }

    public class SearchFilterResult {
        public List<SearchResultRow> rows = new List<SearchResultRow>();
        public Map<String, Integer> sourceTypeCounts = new Map<String, Integer>();
        public Map<String, Integer> usageTypeCounts = new Map<String, Integer>();
    }

    public List<SearchResultRow> searchFieldUsage(String fieldApiName) {
        return searchFieldUsageDetailed(fieldApiName, null, null).rows;
    }

    public SearchFilterResult searchFieldUsageDetailed(
        String fieldApiName,
        List<String> sourceMetadataTypes,
        List<String> usageTypes
    ) {
        String normalizedInput = normalizeInput(fieldApiName);
        if (String.isBlank(normalizedInput)) {
            return new SearchFilterResult();
        }

        if (!Schema.sObjectType.Metadata_Usage__c.isAccessible()) {
            return new SearchFilterResult();
        }

        String targetKey = 'CustomField:' + normalizedInput;
        Boolean isQualifiedFieldName = normalizedInput.contains('.');
        String shortFieldName = isQualifiedFieldName
            ? normalizedInput.substringAfter('.')
            : normalizedInput;

        List<Metadata_Usage__c> usageRecords = isQualifiedFieldName
            ? [
                SELECT Id,
                       Source_Key__c,
                       Source_Type__c,
                       Target_Key__c,
                       Usage_Type__c,
                       Match_Text__c,
                       Context_Snippet__c,
                       Source_Metadata__r.Name
                FROM Metadata_Usage__c
                WHERE Usage_Type__c = 'UsesField'
                  AND (Target_Key__c = :targetKey
                       OR Match_Text__c = :normalizedInput)
                ORDER BY Source_Type__c, Source_Key__c
            ]
            : [
                SELECT Id,
                       Source_Key__c,
                       Source_Type__c,
                       Target_Key__c,
                       Usage_Type__c,
                       Match_Text__c,
                       Context_Snippet__c,
                       Source_Metadata__r.Name
                FROM Metadata_Usage__c
                WHERE Usage_Type__c = 'UsesField'
                  AND (Target_Key__c = :targetKey
                       OR Match_Text__c = :normalizedInput
                       OR Match_Text__c = :shortFieldName)
                ORDER BY Source_Type__c, Source_Key__c
            ];

        return filterRows(mapUsageRows(usageRecords), sourceMetadataTypes, usageTypes);
    }

    public List<SearchResultRow> searchObjectUsage(String objectApiName) {
        return searchObjectUsageDetailed(objectApiName, null, null).rows;
    }

    public SearchFilterResult searchObjectUsageDetailed(
        String objectApiName,
        List<String> sourceMetadataTypes,
        List<String> usageTypes
    ) {
        String normalizedInput = normalizeInput(objectApiName);
        if (String.isBlank(normalizedInput)) {
            return new SearchFilterResult();
        }

        if (!Schema.sObjectType.Metadata_Usage__c.isAccessible()) {
            return new SearchFilterResult();
        }

        List<Metadata_Usage__c> usageRecords = [
            SELECT Id,
                   Source_Key__c,
                   Source_Type__c,
                   Target_Key__c,
                   Usage_Type__c,
                   Match_Text__c,
                   Context_Snippet__c,
                   Source_Metadata__r.Name
            FROM Metadata_Usage__c
            WHERE Usage_Type__c = 'UsesObject'
              AND (Target_Key__c = :('Object:' + normalizedInput)
                   OR Match_Text__c = :normalizedInput)
            ORDER BY Source_Type__c, Source_Key__c
        ];

        return filterRows(mapUsageRows(usageRecords), sourceMetadataTypes, usageTypes);
    }

    private static List<SearchResultRow> mapUsageRows(List<Metadata_Usage__c> usageRecords) {
        List<SearchResultRow> rows = new List<SearchResultRow>();

        for (Metadata_Usage__c usageRecord : usageRecords) {
            SearchResultRow row = new SearchResultRow();
            row.usageId = usageRecord.Id;
            row.sourceMetadataName = usageRecord.Source_Metadata__r != null
                ? usageRecord.Source_Metadata__r.Name
                : usageRecord.Source_Key__c;
            row.sourceMetadataType = usageRecord.Source_Type__c;
            row.targetKey = usageRecord.Target_Key__c;
            row.usageType = usageRecord.Usage_Type__c;
            row.matchText = usageRecord.Match_Text__c;
            row.contextSnippet = usageRecord.Context_Snippet__c;
            rows.add(row);
        }

        return rows;
    }

    private static SearchFilterResult filterRows(
        List<SearchResultRow> rows,
        List<String> sourceMetadataTypes,
        List<String> usageTypes
    ) {
        SearchFilterResult result = new SearchFilterResult();
        Set<String> sourceFilters = normalizeFilters(sourceMetadataTypes);
        Set<String> usageFilters = normalizeFilters(usageTypes);

        for (SearchResultRow row : rows) {
            increment(result.sourceTypeCounts, row.sourceMetadataType);
            increment(result.usageTypeCounts, row.usageType);
            if (!sourceFilters.isEmpty() && !sourceFilters.contains(row.sourceMetadataType)) continue;
            if (!usageFilters.isEmpty() && !usageFilters.contains(row.usageType)) continue;
            result.rows.add(row);
        }
        return result;
    }

    private static Set<String> normalizeFilters(List<String> values) {
        Set<String> normalized = new Set<String>();
        if (values == null) return normalized;
        for (String value : values) {
            if (!String.isBlank(value)) normalized.add(value.trim());
        }
        return normalized;
    }

    private static void increment(Map<String, Integer> counts, String key) {
        if (String.isBlank(key)) return;
        counts.put(key, counts.containsKey(key) ? counts.get(key) + 1 : 1);
    }

    private static String normalizeInput(String inputText) {
        return String.isBlank(inputText) ? null : inputText.trim();
    }
}
