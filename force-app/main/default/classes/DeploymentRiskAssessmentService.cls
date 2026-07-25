public with sharing class DeploymentRiskAssessmentService {
    private AiResponseFormatter formatter = new AiResponseFormatter();

    public AiMetadataCopilotModels.DeploymentCompareResponse assess(
        AiMetadataCopilotModels.DeploymentCompareRequest request
    ) {
        List<Metadata_Snapshot__c> snapshots = loadComparisonSnapshots(request);

        List<AiMetadataCopilotModels.DeploymentFindingRow> findings =
            new List<AiMetadataCopilotModels.DeploymentFindingRow>();

        if (snapshots.size() == 2) {
            findings = new MetadataCompareService().compareSnapshots(
                snapshots[0].Snapshot_Key__c,
                snapshots[1].Snapshot_Key__c
            );
        }

        Decimal readinessScore = 100 - formatter.toScore(findings.size(), 15, 90);
        if (readinessScore < 0) {
            readinessScore = 0;
        }

        String assessmentKey = 'Deployment:' + String.valueOf(System.now().getTime());
        persistAssessment(assessmentKey, request, findings, readinessScore);

        AiMetadataCopilotModels.DeploymentCompareResponse response =
            new AiMetadataCopilotModels.DeploymentCompareResponse();
        response.assessmentKey = assessmentKey;
        response.findings = findings;
        response.readinessScore = readinessScore;
        response.severity = formatter.severityFromScore(100 - readinessScore);
        response.sourceSnapshotKey = snapshots.size() == 2 ? snapshots[0].Snapshot_Key__c : request.sourceSnapshotKey;
        response.targetSnapshotKey = snapshots.size() == 2 ? snapshots[1].Snapshot_Key__c : request.targetSnapshotKey;
        response.addedCount = countFindings(findings, 'MissingInSource');
        response.removedCount = countFindings(findings, 'MissingInTarget');
        response.changedCount = countFindings(findings, 'ChangedMetadata');
        response.comparisonReady = snapshots.size() == 2;
        response.summary = snapshots.size() < 2
            ? 'Select a completed baseline and capture a current snapshot before comparing.'
            : 'Deployment assistant found ' + String.valueOf(findings.size()) + ' comparison finding(s).';
        response.explanation = snapshots.size() < 2
            ? 'The selected snapshots are missing, incomplete, or unavailable. Set a baseline or choose two completed snapshots.'
            : findings.isEmpty()
            ? 'No metadata deltas were detected between the selected snapshots.'
            : 'Findings are grounded in metadata snapshot checksums and presence/absence differences.';
        response.rollbackChecklist = new RollbackChecklistService().buildChecklist(findings);
        response.testChecklist = new RegressionTestRecommendationService().buildChecklistFromFindings(findings);
        return response;
    }

    private static List<Metadata_Snapshot__c> loadComparisonSnapshots(
        AiMetadataCopilotModels.DeploymentCompareRequest request
    ) {
        if (!String.isBlank(request.sourceSnapshotKey) && !String.isBlank(request.targetSnapshotKey)) {
            Map<String, Metadata_Snapshot__c> snapshotsByKey = new Map<String, Metadata_Snapshot__c>();
            for (Metadata_Snapshot__c snapshot : [
                SELECT Id, Snapshot_Key__c, Source_Org_Label__c, CreatedDate
                FROM Metadata_Snapshot__c
                WHERE Snapshot_Type__c = 'EnvironmentCompare'
                  AND Status__c = 'Completed'
                  AND Snapshot_Key__c IN :new Set<String>{
                      request.sourceSnapshotKey,
                      request.targetSnapshotKey
                  }
            ]) {
                snapshotsByKey.put(snapshot.Snapshot_Key__c, snapshot);
            }

            List<Metadata_Snapshot__c> selectedSnapshots = new List<Metadata_Snapshot__c>();
            if (snapshotsByKey.containsKey(request.sourceSnapshotKey)) {
                selectedSnapshots.add(snapshotsByKey.get(request.sourceSnapshotKey));
            }
            if (snapshotsByKey.containsKey(request.targetSnapshotKey)) {
                selectedSnapshots.add(snapshotsByKey.get(request.targetSnapshotKey));
            }
            return selectedSnapshots;
        }

        List<Metadata_Snapshot__c> newestFirst = [
            SELECT Id, Snapshot_Key__c, Source_Org_Label__c, CreatedDate
            FROM Metadata_Snapshot__c
            WHERE Snapshot_Type__c = 'EnvironmentCompare'
              AND Status__c = 'Completed'
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];
        if (newestFirst.size() == 2) {
            return new List<Metadata_Snapshot__c>{ newestFirst[1], newestFirst[0] };
        }
        return newestFirst;
    }

    private static Integer countFindings(
        List<AiMetadataCopilotModels.DeploymentFindingRow> findings,
        String findingType
    ) {
        Integer count = 0;
        for (AiMetadataCopilotModels.DeploymentFindingRow finding : findings) {
            if (finding.findingType == findingType) {
                count++;
            }
        }
        return count;
    }

    private void persistAssessment(
        String assessmentKey,
        AiMetadataCopilotModels.DeploymentCompareRequest request,
        List<AiMetadataCopilotModels.DeploymentFindingRow> findings,
        Decimal readinessScore
    ) {
        if (!MetadataRetentionService.optionalWritesAllowed()) {
            return;
        }

        if (Schema.sObjectType.Deployment_Assessment__c.isCreateable()) {
            Deployment_Assessment__c assessment = new Deployment_Assessment__c();
            assessment.Assessment_Key__c = assessmentKey;
            assessment.Source_Environment__c = request.sourceEnvironment;
            assessment.Target_Environment__c = request.targetEnvironment;
            assessment.Readiness_Score__c = readinessScore;
            assessment.Severity__c = readinessScore < 50 ? 'High' : 'Medium';
            assessment.Summary__c = 'Stored ' + String.valueOf(findings.size()) + ' deployment finding(s).';
            assessment.Rollback_Checklist__c = String.join(
                new RollbackChecklistService().buildChecklist(findings),
                '\n'
            );
            assessment.Test_Checklist__c = String.join(
                new RegressionTestRecommendationService().buildChecklistFromFindings(findings),
                '\n'
            );
            Database.upsert(assessment, Deployment_Assessment__c.Fields.Assessment_Key__c, false);
        }

        if (!findings.isEmpty() && Schema.sObjectType.Deployment_Finding__c.isCreateable()) {
            List<Deployment_Finding__c> findingRecords = new List<Deployment_Finding__c>();
            Integer indexValue = 0;
            for (AiMetadataCopilotModels.DeploymentFindingRow finding : findings) {
                Deployment_Finding__c record = new Deployment_Finding__c();
                record.Finding_Key__c = assessmentKey + ':' + String.valueOf(indexValue);
                record.Assessment_Key__c = assessmentKey;
                record.Finding_Type__c = finding.findingType;
                record.Severity__c = finding.severity;
                record.Metadata_Key__c = finding.metadataKey;
                record.Summary__c = finding.summary;
                record.Recommendation__c = finding.recommendation;
                findingRecords.add(record);
                indexValue++;
            }
            Database.upsert(findingRecords, Deployment_Finding__c.Fields.Finding_Key__c, false);
        }
    }
}
