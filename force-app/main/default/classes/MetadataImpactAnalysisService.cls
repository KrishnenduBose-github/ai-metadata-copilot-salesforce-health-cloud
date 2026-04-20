public with sharing class MetadataImpactAnalysisService {
    /*
     * This service turns search results into a simple readable summary
     * and stores it in Impact_Assessment__c.
     */

    public class ImpactSummaryResult {
        @AuraEnabled public String queryText;
        @AuraEnabled public String queryType;
        @AuraEnabled public Integer matchCount;
        @AuraEnabled public String impactLevel;
        @AuraEnabled public String summary;
        @AuraEnabled public Id assessmentId;
    }

    private MetadataSearchService searchService;

    public MetadataImpactAnalysisService() {
        this(new MetadataSearchService());
    }

    public MetadataImpactAnalysisService(MetadataSearchService searchService) {
        this.searchService = searchService;
    }

    public ImpactSummaryResult analyzeFieldUsage(String fieldApiName) {
        List<MetadataSearchService.SearchResultRow> rows = searchService.searchFieldUsage(fieldApiName);
        return buildAndStoreSummary(fieldApiName, 'FieldUsage', rows);
    }

    public ImpactSummaryResult analyzeObjectUsage(String objectApiName) {
        List<MetadataSearchService.SearchResultRow> rows = searchService.searchObjectUsage(objectApiName);
        return buildAndStoreSummary(objectApiName, 'ObjectUsage', rows);
    }

    private static ImpactSummaryResult buildAndStoreSummary(
        String queryText,
        String queryType,
        List<MetadataSearchService.SearchResultRow> rows
    ) {
        Integer matchCount = rows == null ? 0 : rows.size();

        ImpactSummaryResult result = new ImpactSummaryResult();
        result.queryText = queryText;
        result.queryType = queryType;
        result.matchCount = matchCount;
        result.impactLevel = calculateImpactLevel(matchCount);
        result.summary = buildSummaryText(queryText, queryType, rows, result.impactLevel);

        Impact_Assessment__c assessment = new Impact_Assessment__c();
        assessment.Query_Text__c = queryText;
        assessment.Query_Type__c = queryType;
        assessment.Summary__c = result.summary;
        assessment.Impact_Level__c = result.impactLevel;
        assessment.Match_Count__c = matchCount;
        insert assessment;

        result.assessmentId = assessment.Id;
        return result;
    }

    private static String calculateImpactLevel(Integer matchCount) {
        if (matchCount >= 10) {
            return 'High';
        }

        if (matchCount >= 4) {
            return 'Medium';
        }

        return 'Low';
    }

    private static String buildSummaryText(
        String queryText,
        String queryType,
        List<MetadataSearchService.SearchResultRow> rows,
        String impactLevel
    ) {
        Integer matchCount = rows == null ? 0 : rows.size();

        String summary =
            queryType
            + ' search for '
            + queryText
            + ' found '
            + String.valueOf(matchCount)
            + ' matching usage relationship(s). '
            + 'Impact level: '
            + impactLevel
            + '.';

        if (matchCount == 0) {
            return summary + ' No dependent metadata was found in the current index.';
        }

        List<String> examples = new List<String>();
        Integer limitSize = Math.min(3, rows.size());

        for (Integer index = 0; index < limitSize; index++) {
            MetadataSearchService.SearchResultRow row = rows[index];
            examples.add(
                row.sourceMetadataType
                + ' '
                + row.sourceMetadataName
                + ' references '
                + row.matchText
            );
        }

        return summary + ' Example dependencies: ' + String.join(examples, '; ') + '.';
    }
}
