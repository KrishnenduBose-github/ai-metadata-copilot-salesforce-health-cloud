public with sharing class DeploymentWorkspaceService {
    public AiMetadataCopilotModels.DeploymentWorkspaceState getState() {
        AiMetadataCopilotModels.DeploymentWorkspaceState state =
            new AiMetadataCopilotModels.DeploymentWorkspaceState();
        state.snapshots = new List<AiMetadataCopilotModels.SnapshotSummary>();

        if (!hasSnapshotSchema()) {
            state.snapshotStorageReady = false;
            state.setupMessage = 'Deploy workspace fields are missing. Deploy the Metadata Snapshot and Metadata Component Version fields, then refresh the page.';
            return state;
        }

        state.snapshotStorageReady = true;
        for (Metadata_Snapshot__c record : [
            SELECT Snapshot_Key__c, Source_Org_Label__c, Item_Count__c, Status__c, Completed_On__c
            FROM Metadata_Snapshot__c
            WHERE Snapshot_Type__c = 'EnvironmentCompare'
              AND Status__c = 'Completed'
            ORDER BY Completed_On__c DESC
            LIMIT 50
        ]) {
            state.snapshots.add(toSummary(record));
        }
        state.setupMessage = state.snapshots.isEmpty()
            ? 'Set a baseline to start a release comparison.'
            : null;
        return state;
    }

    public AiMetadataCopilotModels.DeploymentCaptureResponse captureSnapshot(String label) {
        AiMetadataCopilotModels.DeploymentCaptureResponse response =
            new AiMetadataCopilotModels.DeploymentCaptureResponse();
        if (!hasSnapshotSchema()) {
            response.saved = false;
            response.message = 'Deploy workspace fields are missing. Deploy the snapshot metadata first.';
            return response;
        }

        MetadataSnapshotService.SnapshotResult captureResult =
            new EnvironmentSnapshotService().captureCurrentEnvironment(
                String.isBlank(label) ? 'Release Snapshot' : label.trim()
            );
        response.saved = captureResult.saved;
        response.message = captureResult.saved
            ? 'Snapshot captured successfully.'
            : String.join(captureResult.messages, ' ');
        if (captureResult.saved) {
            response.snapshot = findSummary(captureResult.snapshotKey);
        }
        return response;
    }

    public AiMetadataCopilotModels.DeploymentCaptureResponse captureAndCompare(
        String sourceSnapshotKey,
        String currentLabel,
        String targetEnvironment
    ) {
        AiMetadataCopilotModels.DeploymentCaptureResponse response =
            captureSnapshot(currentLabel);
        if (!response.saved || response.snapshot == null) {
            return response;
        }

        AiMetadataCopilotModels.DeploymentCompareRequest request =
            new AiMetadataCopilotModels.DeploymentCompareRequest();
        request.sourceSnapshotKey = sourceSnapshotKey;
        request.targetSnapshotKey = response.snapshot.snapshotKey;
        request.sourceEnvironment = sourceSnapshotKey;
        request.targetEnvironment = String.isBlank(targetEnvironment)
            ? response.snapshot.label
            : targetEnvironment.trim();
        response.comparison = new DeploymentRiskAssessmentService().assess(request);
        return response;
    }

    private static AiMetadataCopilotModels.SnapshotSummary findSummary(String snapshotKey) {
        List<Metadata_Snapshot__c> records = [
            SELECT Snapshot_Key__c, Source_Org_Label__c, Item_Count__c, Status__c, Completed_On__c
            FROM Metadata_Snapshot__c
            WHERE Snapshot_Key__c = :snapshotKey
            LIMIT 1
        ];
        return records.isEmpty() ? null : toSummary(records[0]);
    }

    private static AiMetadataCopilotModels.SnapshotSummary toSummary(Metadata_Snapshot__c record) {
        AiMetadataCopilotModels.SnapshotSummary summary =
            new AiMetadataCopilotModels.SnapshotSummary();
        summary.snapshotKey = record.Snapshot_Key__c;
        summary.label = record.Source_Org_Label__c;
        summary.componentCount = record.Item_Count__c == null ? 0 : Integer.valueOf(record.Item_Count__c);
        summary.capturedOn = record.Completed_On__c;
        summary.status = record.Status__c;
        return summary;
    }

    private static Boolean hasSnapshotSchema() {
        return Schema.sObjectType.Metadata_Snapshot__c.isAccessible()
            && Schema.sObjectType.Metadata_Snapshot__c.isCreateable()
            && Schema.sObjectType.Metadata_Component_Version__c.isAccessible()
            && Schema.sObjectType.Metadata_Component_Version__c.isCreateable()
            && Schema.sObjectType.Metadata_Snapshot__c.fields.getMap().containsKey('Snapshot_Key__c')
            && Schema.sObjectType.Metadata_Component_Version__c.fields.getMap().containsKey('Snapshot_Key__c');
    }
}
