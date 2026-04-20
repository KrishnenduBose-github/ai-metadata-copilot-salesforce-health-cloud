public with sharing class MetadataExtractionOrchestrator {
    public class RefreshRunResult {
        @AuraEnabled public String snapshotKey;
        @AuraEnabled public Integer indexedItems;
        @AuraEnabled public Integer usageRelationships;
        @AuraEnabled public List<String> messages;

        public RefreshRunResult() {
            this.messages = new List<String>();
        }
    }

    private MetadataExtractionService extractionService;
    private MetadataIndexerService indexerService;
    private MetadataUsageAnalyzerService usageAnalyzerService;
    private MetadataSnapshotService snapshotService;

    public MetadataExtractionOrchestrator() {
        this(
            new MetadataExtractionService(),
            new MetadataIndexerService(),
            new MetadataUsageAnalyzerService(),
            new MetadataSnapshotService()
        );
    }

    public MetadataExtractionOrchestrator(
        MetadataExtractionService extractionService,
        MetadataIndexerService indexerService,
        MetadataUsageAnalyzerService usageAnalyzerService,
        MetadataSnapshotService snapshotService
    ) {
        this.extractionService = extractionService;
        this.indexerService = indexerService;
        this.usageAnalyzerService = usageAnalyzerService;
        this.snapshotService = snapshotService;
    }

    public RefreshRunResult refreshMetadata(String sourceOrgLabel) {
        List<MetadataExtractionService.ExtractedMetadataItem> extractedItems =
            extractionService.extractAllSupportedMetadata();
        MetadataSnapshotService.SnapshotResult snapshotResult =
            snapshotService.saveSnapshot('MetadataRefresh', sourceOrgLabel, null, extractedItems);
        MetadataIndexerService.IndexingResult indexingResult =
            indexerService.indexMetadataItems(extractedItems);
        MetadataUsageAnalyzerService.AnalysisResult analysisResult =
            usageAnalyzerService.analyzeAndStoreUsage(extractedItems);

        RefreshRunResult result = new RefreshRunResult();
        result.snapshotKey = snapshotResult.snapshotKey;
        result.indexedItems = indexingResult.successCount;
        result.usageRelationships = analysisResult.successCount;
        result.messages.addAll(indexingResult.errors);
        result.messages.addAll(analysisResult.errors);
        return result;
    }
}
