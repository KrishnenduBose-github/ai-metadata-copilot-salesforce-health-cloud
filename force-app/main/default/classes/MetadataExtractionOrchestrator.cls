public with sharing class MetadataExtractionOrchestrator {
    public class RefreshRunResult {
        @AuraEnabled public String snapshotKey;
        @AuraEnabled public String status;
        @AuraEnabled public String warningSummary;
        @AuraEnabled public Integer indexedItems;
        @AuraEnabled public Integer indexedSkippedCount;
        @AuraEnabled public Integer usageRelationships;
        @AuraEnabled public Integer usageSkippedCount;
        @AuraEnabled public Boolean snapshotSaved;
        @AuraEnabled public Boolean retentionCleanupApplied;
        @AuraEnabled public List<String> messages;

        public RefreshRunResult() {
            this.messages = new List<String>();
            this.status = 'Success';
            this.snapshotSaved = false;
            this.retentionCleanupApplied = false;
            this.indexedItems = 0;
            this.indexedSkippedCount = 0;
            this.usageRelationships = 0;
            this.usageSkippedCount = 0;
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
            // Tooling API extraction performs callouts, so storage cleanup DML must happen after this step.
            List<MetadataExtractionService.ExtractedMetadataItem> extractedItems =
                extractionService.extractAllSupportedMetadata();

            MetadataRetentionService.RetentionResult retentionResult =
                new MetadataRetentionService().cleanupBeforeRefresh();
            result.retentionCleanupApplied = retentionResult.cleanupApplied;
            result.messages.addAll(retentionResult.messages);

            MetadataIndexerService.IndexingResult indexingResult =
                indexerService.indexMetadataItems(extractedItems);
            MetadataUsageAnalyzerService.AnalysisResult analysisResult =
                usageAnalyzerService.analyzeAndStoreUsage(
                    extractedItems,
                    indexingResult.successfulMetadataKeys
                );

            MetadataSnapshotService.SnapshotResult snapshotResult = new MetadataSnapshotService.SnapshotResult();
            snapshotResult.snapshotKey = 'MetadataRefresh:' + sourceOrgLabel + ':CurrentOrg';
            if (!MetadataRetentionService.storagePressureLikely()) {
                snapshotResult = snapshotService.saveSnapshot(
                    'MetadataRefresh',
                    sourceOrgLabel,
                    null,
                    extractedItems
                );
                result.snapshotSaved = snapshotResult.saved;
                result.messages.addAll(snapshotResult.messages);
            } else {
                result.messages.add('Snapshot persistence was skipped to preserve storage for the live metadata index.');
            }

            result.snapshotKey = snapshotResult.snapshotKey;
            result.indexedItems = indexingResult.successCount;
            result.indexedSkippedCount = indexingResult.skippedCount;
            result.usageRelationships = analysisResult.successCount;
            result.usageSkippedCount = analysisResult.skippedSourceCount + analysisResult.errorCount;
            result.messages.addAll(indexingResult.errors);
            result.messages.addAll(analysisResult.errors);
            result.warningSummary = buildWarningSummary(result.messages);
            if (result.retentionCleanupApplied) {
                result.status = 'StorageRecoveryApplied';
            } else if (!String.isBlank(result.warningSummary)) {
                result.status = 'Partial';
            }
        } catch (System.CalloutException calloutError) {
            result.status = 'Error';
            result.messages.add(
                'Metadata refresh failed: Tooling API callout error. Verify the Named Credential SalesforceTooling is configured. '
                + calloutError.getMessage()
            );
            result.warningSummary = buildWarningSummary(result.messages);
            MetadataLogger.error('MetadataExtractionOrchestrator', 'Callout failed during refresh', calloutError);
        } catch (DmlException dmlError) {
            if (!MetadataStorageUtility.isStorageLimitException(dmlError)) {
                result.status = 'Error';
                result.messages.add('Metadata refresh failed: DML error. ' + dmlError.getMessage());
                MetadataLogger.error('MetadataExtractionOrchestrator', 'DML error during refresh', dmlError);
            } else {
                result.status = 'Partial';
                result.messages.add('Metadata refresh partially completed. Storage limit reached. Free up data storage and try again.');
            }
            result.warningSummary = buildWarningSummary(result.messages);
        } catch (Exception ex) {
            result.status = 'Error';
            result.messages.add('Metadata refresh failed: ' + ex.getMessage());
            result.warningSummary = buildWarningSummary(result.messages);
            MetadataLogger.error('MetadataExtractionOrchestrator', 'Unexpected error during refresh', ex);
        }

        return result;
    }

    private static String buildWarningSummary(List<String> messages) {
        if (messages == null || messages.isEmpty()) {
            return null;
        }

        List<String> uniqueMessages = new List<String>();
        Set<String> seen = new Set<String>();
        for (String message : messages) {
            if (String.isBlank(message) || seen.contains(message)) {
                continue;
            }
            seen.add(message);
            uniqueMessages.add(message);
        }
        return String.join(uniqueMessages, ' ');
    }
}
