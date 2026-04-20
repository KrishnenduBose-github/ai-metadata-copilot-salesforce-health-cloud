public with sharing class PermissionSetExposureService {
    public List<AiMetadataCopilotModels.SecurityFindingRow> buildPermissionSetFindings(
        List<FieldPermissions> permissions,
        String runKey,
        String sensitivityLevel
    ) {
        List<AiMetadataCopilotModels.SecurityFindingRow> findings =
            new List<AiMetadataCopilotModels.SecurityFindingRow>();

        for (FieldPermissions permissionRecord : permissions) {
            if (permissionRecord.Parent == null || permissionRecord.Parent.IsOwnedByProfile) {
                continue;
            }

            if (!permissionRecord.PermissionsRead && !permissionRecord.PermissionsEdit) {
                continue;
            }

            AiMetadataCopilotModels.SecurityFindingRow finding =
                new AiMetadataCopilotModels.SecurityFindingRow();
            finding.findingType = permissionRecord.PermissionsEdit ? 'PermissionSetEditAccess' : 'PermissionSetReadAccess';
            finding.severity = sensitivityLevel;
            finding.objectApiName = permissionRecord.SObjectType;
            finding.fieldApiName = permissionRecord.Field;
            finding.permissionArtifact = permissionRecord.Parent.Name;
            finding.summary = permissionRecord.Parent.Name + ' exposes ' + permissionRecord.Field + '.';
            finding.recommendation = 'Review whether ' + permissionRecord.Parent.Name + ' should keep access to this sensitive field.';
            findings.add(finding);
        }

        return findings;
    }
}
