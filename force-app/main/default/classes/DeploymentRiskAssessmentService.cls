public with sharing class DeploymentRiskAssessmentService {
    private AiResponseFormatter formatter = new AiResponseFormatter();

    public AiMetadataCopilotModels.DeploymentCompareResponse assess(
        AiMetadataCopilotModels.DeploymentCompareRequest request
    ) {
        MetadataSnapshotService snapshotService = new MetadataSnapshotService();
        Metadata_Snapshot__c latestSnapshot = snapshotService.getLatestSnapshot('EnvironmentCompare');

        if (latestSnapshot == null) {
            EnvironmentSnapshotService environmentSnapshotService = new EnvironmentSnapshotService();
            environmentSnapshotService.captureCurrentEnvironment(request.sourceEnvironment);
            latestSnapshot = snapshotService.getLatestSnapshot('EnvironmentCompare');
        }

        List<Metadata_Snapshot__c> snapshots = [
            SELECT Id, Snapshot_Key__c, Source_Org_Label__c, CreatedDate
            FROM Metadata_Snapshot__c
            WHERE Snapshot_Type__c = 'EnvironmentCompare'
            ORDER BY CreatedDate DESC
            LIMIT 2
        ];

        List<AiMetadataCopilotModels.DeploymentFindingRow> findings =
            new List<AiMetadataCopilotModels.DeploymentFindingRow>();

        if (snapshots.size() >= 2) {
            findings = new MetadataCompareService().compareSnapshots(
                snapshots[1].Snapshot_Key__c,
                snapshots[0].Snapshot_Key__c
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
        response.summary = 'Deployment assistant found ' + String.valueOf(findings.size()) + ' comparison finding(s).';
        response.explanation = findings.isEmpty()
            ? 'No metadata deltas were detected between the most recent environment snapshots.'
            : 'Findings are grounded in metadata snapshot checksums and presence/absence differences.';
        response.rollbackChecklist = new RollbackChecklistService().buildChecklist(findings);
        response.testChecklist = new RegressionTestRecommendationService().buildChecklistFromFindings(findings);
        return response;
    }

    private void persistAssessment(
        String assessmentKey,
        AiMetadataCopilotModels.DeploymentCompareRequest request,
        List<AiMetadataCopilotModels.DeploymentFindingRow> findings,
        Decimal readinessScore
    ) {
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
