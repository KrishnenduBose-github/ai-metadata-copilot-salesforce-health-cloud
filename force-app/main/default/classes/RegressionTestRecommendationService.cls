public with sharing class RegressionTestRecommendationService {
    public List<String> buildChecklistFromFindings(
        List<AiMetadataCopilotModels.DeploymentFindingRow> findings
    ) {
        List<String> recommendations = new List<String>{
            'Run smoke tests for metadata search and impact analysis.',
            'Validate access to sensitive Health Cloud fields after deployment.'
        };

        for (AiMetadataCopilotModels.DeploymentFindingRow finding : findings) {
            if (!String.isBlank(finding.metadataKey)) {
                recommendations.add('Test metadata path related to ' + finding.metadataKey + '.');
            }
        }

        return recommendations;
    }

    public List<String> buildImpactAreas(String queryText, List<AiMetadataCopilotModels.MatchedComponent> components) {
        List<String> areas = new List<String>{
            'Re-test flows and Apex classes that reference ' + queryText + '.'
        };

        for (AiMetadataCopilotModels.MatchedComponent component : components) {
            areas.add('Regression area: ' + component.metadataType + ' ' + component.metadataName);
        }

        return areas;
    }
}
