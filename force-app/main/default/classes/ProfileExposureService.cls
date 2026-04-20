public with sharing class ProfileExposureService {
    public List<AiMetadataCopilotModels.SecurityFindingRow> buildProfileFindings(
        List<FieldPermissions> permissions,
        String sensitivityLevel
    ) {
        List<AiMetadataCopilotModels.SecurityFindingRow> findings =
            new List<AiMetadataCopilotModels.SecurityFindingRow>();

        for (FieldPermissions permissionRecord : permissions) {
            if (permissionRecord.Parent == null || !permissionRecord.Parent.IsOwnedByProfile) {
                continue;
            }

            if (!permissionRecord.PermissionsRead && !permissionRecord.PermissionsEdit) {
                continue;
            }

            String profileName = permissionRecord.Parent.Profile != null
                ? permissionRecord.Parent.Profile.Name
                : permissionRecord.Parent.Name;

            AiMetadataCopilotModels.SecurityFindingRow finding =
                new AiMetadataCopilotModels.SecurityFindingRow();
            finding.findingType = permissionRecord.PermissionsEdit ? 'ProfileEditAccess' : 'ProfileReadAccess';
            finding.severity = sensitivityLevel;
            finding.objectApiName = permissionRecord.SObjectType;
            finding.fieldApiName = permissionRecord.Field;
            finding.permissionArtifact = profileName;
            finding.summary = profileName + ' exposes ' + permissionRecord.Field + '.';
            finding.recommendation = 'Confirm whether profile-level access should be replaced by permission sets.';
            findings.add(finding);
        }

        return findings;
    }
}
