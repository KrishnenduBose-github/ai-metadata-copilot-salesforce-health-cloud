public with sharing class AiPromptGroundingService {
    public List<AiMetadataCopilotModels.MatchedComponent> buildGroundedComponents(
        List<MetadataSearchService.SearchResultRow> searchRows
    ) {
        List<AiMetadataCopilotModels.MatchedComponent> components =
            new List<AiMetadataCopilotModels.MatchedComponent>();

        for (MetadataSearchService.SearchResultRow row : searchRows) {
            AiMetadataCopilotModels.MatchedComponent component =
                new AiMetadataCopilotModels.MatchedComponent();
            component.usageId = row.usageId;
            component.metadataKey = row.targetKey;
            component.metadataName = row.sourceMetadataName;
            component.metadataType = row.sourceMetadataType;
            component.usageType = row.usageType;
            component.context = row.contextSnippet;
            components.add(component);
        }

        return components;
    }

    public String buildSecurityGroundingSummary(List<AiMetadataCopilotModels.SecurityFindingRow> findings) {
        if (findings == null || findings.isEmpty()) {
            return 'No sensitive exposure was detected in the current grounded audit scope.';
        }

        return 'Grounded using FieldPermissions, PermissionSet, and profile-derived access records.';
    }
}
