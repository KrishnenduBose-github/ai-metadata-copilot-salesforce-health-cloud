public with sharing class MetadataExplainabilityService {
    public String buildSearchExplanation(List<AiMetadataCopilotModels.MatchedComponent> components) {
        if (components == null || components.isEmpty()) {
            return 'No grounded metadata relationships were found in the current snapshot and usage index.';
        }

        Integer limitSize = components.size() > 3 ? 3 : components.size();
        List<String> reasons = new List<String>();

        for (Integer index = 0; index < limitSize; index++) {
            AiMetadataCopilotModels.MatchedComponent component = components[index];
            reasons.add(
                component.metadataType + ' ' + component.metadataName + ' matched as ' + component.usageType
            );
        }

        return 'Grounded using stored metadata relationships. Example matches: ' + String.join(reasons, '; ') + '.';
    }

    public List<String> buildSearchRecommendations(String queryType, Integer matchCount) {
        List<String> recommendations = new List<String>();
        recommendations.add('Refresh metadata before major analysis if the org changed recently.');

        if (queryType == 'ObjectUsage') {
            recommendations.add('Review flows, Apex classes, and dependent fields before object model changes.');
        } else {
            recommendations.add('Review dependent Apex, flows, and validation logic before field changes.');
        }

        if (matchCount == 0) {
            recommendations.add('If you expected results, create or refresh metadata references before searching again.');
        }

        return recommendations;
    }

    public List<String> buildImpactRecommendations(String severity) {
        List<String> recommendations = new List<String>();
        recommendations.add('Re-run metadata refresh immediately before deployment.');
        recommendations.add('Review deployment warnings with an admin or release manager.');

        if (severity == 'High' || severity == 'Critical') {
            recommendations.add('Schedule focused regression testing and a rollback checkpoint.');
        } else {
            recommendations.add('Add targeted smoke tests for the dependent components listed.');
        }

        return recommendations;
    }
}
