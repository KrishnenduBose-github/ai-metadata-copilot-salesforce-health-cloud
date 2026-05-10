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
        RefreshRunResult result = new RefreshRunResult();

        try {
            List<MetadataExtractionService.ExtractedMetadataItem> extractedItems =
                extractionService.extractAllSupportedMetadata();

            MetadataSnapshotService.SnapshotResult snapshotResult = snapshotService.saveSnapshot(
                'MetadataRefresh',
                sourceOrgLabel,
                null,
                extractedItems
            );

            MetadataIndexerService.IndexingResult indexingResult =
                indexerService.indexMetadataItems(extractedItems);
            MetadataUsageAnalyzerService.AnalysisResult analysisResult =
                usageAnalyzerService.analyzeAndStoreUsage(extractedItems);

            result.snapshotKey = snapshotResult.snapshotKey;
            result.indexedItems = indexingResult.successCount;
            result.usageRelationships = analysisResult.successCount;
            result.messages.addAll(snapshotResult.messages);
            result.messages.addAll(indexingResult.errors);
            result.messages.addAll(analysisResult.errors);
        } catch (System.CalloutException calloutError) {
            result.messages.add(
                'Metadata refresh failed: Tooling API callout error. Verify the Named Credential SalesforceTooling is configured. '
                + calloutError.getMessage()
            );
            MetadataLogger.error('MetadataExtractionOrchestrator', 'Callout failed during refresh', calloutError);
        } catch (DmlException dmlError) {
            if (!MetadataStorageUtility.isStorageLimitException(dmlError)) {
                result.messages.add('Metadata refresh failed: DML error. ' + dmlError.getMessage());
                MetadataLogger.error('MetadataExtractionOrchestrator', 'DML error during refresh', dmlError);
            } else {
                result.messages.add('Metadata refresh partially completed. Storage limit reached. Free up data storage and try again.');
            }
        } catch (Exception ex) {
            result.messages.add('Metadata refresh failed: ' + ex.getMessage());
            MetadataLogger.error('MetadataExtractionOrchestrator', 'Unexpected error during refresh', ex);
        }

        return result;
    }
}
