public with sharing class SharingRiskService {
    public List<AiMetadataCopilotModels.SecurityFindingRow> buildSharingFindings(
        String objectApiName,
        String fieldApiName,
        String sensitivityLevel,
        Integer accessFindingCount
    ) {
        List<AiMetadataCopilotModels.SecurityFindingRow> findings =
            new List<AiMetadataCopilotModels.SecurityFindingRow>();

        if (accessFindingCount < 3) {
            return findings;
        }

        AiMetadataCopilotModels.SecurityFindingRow finding =
            new AiMetadataCopilotModels.SecurityFindingRow();
        finding.findingType = 'BroadExposure';
        finding.severity = sensitivityLevel == 'Critical' ? 'Critical' : 'High';
        finding.objectApiName = objectApiName;
        finding.fieldApiName = fieldApiName;
        finding.permissionArtifact = 'Org Access Pattern';
        finding.summary = 'The field appears across multiple profiles or permission sets, which increases sharing risk.';
        finding.recommendation = 'Review org-wide defaults, permission set design, and whether access can be segmented.';
        findings.add(finding);
        return findings;
    }
}
