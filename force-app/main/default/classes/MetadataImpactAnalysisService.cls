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

    public ImpactSummaryResult analyzeFieldUsage(
        List<MetadataSearchService.SearchResultRow> rows,
        String fieldApiName
    ) {
        return buildAndStoreSummary(fieldApiName, 'FieldUsage', rows);
    }

    public ImpactSummaryResult analyzeObjectUsage(String objectApiName) {
        List<MetadataSearchService.SearchResultRow> rows = searchService.searchObjectUsage(objectApiName);
        return buildAndStoreSummary(objectApiName, 'ObjectUsage', rows);
    }

    public ImpactSummaryResult analyzeObjectUsage(
        List<MetadataSearchService.SearchResultRow> rows,
        String objectApiName
    ) {
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

        Impact_Assessment__c assessment = persistSummary(
            queryText,
            queryType,
            result.summary,
            result.impactLevel,
            matchCount
        );
        result.assessmentId = assessment.Id;
        return result;
    }

    private static Impact_Assessment__c persistSummary(
        String queryText,
        String queryType,
        String summary,
        String impactLevel,
        Integer matchCount
    ) {
        Impact_Assessment__c assessment = findReusableAssessment(queryText, queryType);
        if (assessment == null) {
            assessment = findOldestAssessmentForRecycle();
        }
        Boolean shouldInsert = assessment == null;

        if (shouldInsert) {
            assessment = new Impact_Assessment__c();
        }

        assessment.Query_Text__c = queryText;
        assessment.Query_Type__c = queryType;
        assessment.Summary__c = summary;
        assessment.Impact_Level__c = impactLevel;
        assessment.Match_Count__c = matchCount;

        try {
            if (shouldInsert) {
                if (Schema.sObjectType.Impact_Assessment__c.isCreateable()) {
                    insert assessment;
                }
            } else {
                if (Schema.sObjectType.Impact_Assessment__c.isUpdateable()) {
                    update assessment;
                }
            }
        } catch (DmlException dmlError) {
            if (!MetadataStorageUtility.isStorageLimitException(dmlError) || shouldInsert == false) {
                throw dmlError;
            }

            Impact_Assessment__c recycledAssessment = findOldestAssessmentForRecycle();
            if (recycledAssessment == null) {
                throw dmlError;
            }

            recycledAssessment.Query_Text__c = queryText;
            recycledAssessment.Query_Type__c = queryType;
            recycledAssessment.Summary__c = summary;
            recycledAssessment.Impact_Level__c = impactLevel;
            recycledAssessment.Match_Count__c = matchCount;
            if (Schema.sObjectType.Impact_Assessment__c.isUpdateable()) {
                update recycledAssessment;
            }
            return recycledAssessment;
        }

        return assessment;
    }

    private static Impact_Assessment__c findReusableAssessment(String queryText, String queryType) {
        if (!Schema.sObjectType.Impact_Assessment__c.isAccessible()) {
            return null;
        }
        List<Impact_Assessment__c> assessments = [
            SELECT Id, Query_Text__c, Query_Type__c, Summary__c, Impact_Level__c, Match_Count__c
            FROM Impact_Assessment__c
            WHERE Query_Text__c = :queryText
              AND Query_Type__c = :queryType
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        return assessments.isEmpty() ? null : assessments[0];
    }

    private static Impact_Assessment__c findOldestAssessmentForRecycle() {
        if (!Schema.sObjectType.Impact_Assessment__c.isAccessible()) {
            return null;
        }
        List<Impact_Assessment__c> assessments = [
            SELECT Id, Query_Text__c, Query_Type__c, Summary__c, Impact_Level__c, Match_Count__c
            FROM Impact_Assessment__c
            ORDER BY LastModifiedDate ASC
            LIMIT 1
        ];

        return assessments.isEmpty() ? null : assessments[0];
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
