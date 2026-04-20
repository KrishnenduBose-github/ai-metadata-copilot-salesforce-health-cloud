public with sharing class EnvironmentSnapshotService {
    private MetadataExtractionService extractionService;
    private MetadataSnapshotService snapshotService;

    public EnvironmentSnapshotService() {
        this.extractionService = new MetadataExtractionService();
        this.snapshotService = new MetadataSnapshotService();
    }

    public MetadataSnapshotService.SnapshotResult captureCurrentEnvironment(String environmentLabel) {
        return snapshotService.saveSnapshot(
            'EnvironmentCompare',
            environmentLabel,
            null,
            extractionService.extractAllSupportedMetadata()
        );
    }
}
