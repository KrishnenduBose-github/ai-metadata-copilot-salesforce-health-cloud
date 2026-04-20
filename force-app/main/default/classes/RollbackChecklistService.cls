public with sharing class RollbackChecklistService {
    public List<String> buildChecklist(List<AiMetadataCopilotModels.DeploymentFindingRow> findings) {
        List<String> checklist = new List<String>{
            'Keep a recent metadata snapshot before deployment.',
            'Prepare a backout deployment package for changed components.',
            'Confirm release owner and admin escalation contacts.'
        };

        if (findings != null && !findings.isEmpty()) {
            checklist.add('Review missing target metadata and component deltas before release approval.');
        }

        return checklist;
    }
}
