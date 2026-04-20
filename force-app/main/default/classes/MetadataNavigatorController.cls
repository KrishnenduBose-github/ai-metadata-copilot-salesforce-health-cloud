public with sharing class MetadataNavigatorController {
    /*
     * This controller connects the LWC to the backend services.
     */

    public class RefreshResponse {
        @AuraEnabled public Integer indexedItems;
        @AuraEnabled public Integer indexedSuccessCount;
        @AuraEnabled public Integer indexedErrorCount;
        @AuraEnabled public Integer usageRelationships;
        @AuraEnabled public Integer usageSuccessCount;
        @AuraEnabled public Integer usageErrorCount;
        @AuraEnabled public List<String> messages;

        public RefreshResponse() {
            this.messages = new List<String>();
        }
    }

    public class SearchResponse {
        @AuraEnabled public String queryText;
        @AuraEnabled public String queryType;
        @AuraEnabled public Integer matchCount;
        @AuraEnabled public String impactLevel;
        @AuraEnabled public String summary;
        @AuraEnabled public Id assessmentId;
        @AuraEnabled public List<MetadataSearchService.SearchResultRow> rows;
    }

    @AuraEnabled
    public static RefreshResponse refreshMetadataIndex() {
        RefreshResponse response = new RefreshResponse();

        MetadataExtractionService extractionService = new MetadataExtractionService();
        List<MetadataExtractionService.ExtractedMetadataItem> extractedItems =
            extractionService.extractAllSupportedMetadata();

        MetadataIndexerService.IndexingResult indexingResult =
            new MetadataIndexerService().indexMetadataItems(extractedItems);
        MetadataUsageAnalyzerService.AnalysisResult analysisResult =
            new MetadataUsageAnalyzerService().analyzeAndStoreUsage(extractedItems);

        response.indexedItems = indexingResult.totalItems;
        response.indexedSuccessCount = indexingResult.successCount;
        response.indexedErrorCount = indexingResult.errorCount;
        response.usageRelationships = analysisResult.totalRelationships;
        response.usageSuccessCount = analysisResult.successCount;
        response.usageErrorCount = analysisResult.errorCount;
        response.messages.addAll(indexingResult.errors);
        response.messages.addAll(analysisResult.errors);

        return response;
    }

    @AuraEnabled
    public static SearchResponse searchMetadata(String queryText, String queryType) {
        if (String.isBlank(queryText)) {
            throw new AuraHandledException('Please enter a field or object API name.');
        }

        if (String.isBlank(queryType)) {
            throw new AuraHandledException('Please choose a query type.');
        }

        MetadataSearchService searchService = new MetadataSearchService();
        MetadataImpactAnalysisService impactService = new MetadataImpactAnalysisService(searchService);

        SearchResponse response = new SearchResponse();
        response.queryText = queryText;
        response.queryType = queryType;

        if (queryType == 'FieldUsage') {
            MetadataImpactAnalysisService.ImpactSummaryResult summaryResult =
                impactService.analyzeFieldUsage(queryText);
            response.matchCount = summaryResult.matchCount;
            response.impactLevel = summaryResult.impactLevel;
            response.summary = summaryResult.summary;
            response.assessmentId = summaryResult.assessmentId;
            response.rows = searchService.searchFieldUsage(queryText);
            return response;
        }

        if (queryType == 'ObjectUsage') {
            MetadataImpactAnalysisService.ImpactSummaryResult summaryResult =
                impactService.analyzeObjectUsage(queryText);
            response.matchCount = summaryResult.matchCount;
            response.impactLevel = summaryResult.impactLevel;
            response.summary = summaryResult.summary;
            response.assessmentId = summaryResult.assessmentId;
            response.rows = searchService.searchObjectUsage(queryText);
            return response;
        }

        throw new AuraHandledException('Unsupported query type. Use FieldUsage or ObjectUsage.');
    }
}
