public with sharing class FieldAccessAuditService {
    public List<FieldPermissions> findFieldPermissions(String objectApiName, String fieldApiName) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            return new List<FieldPermissions>();
        }

        String fullFieldName = objectApiName + '.' + fieldApiName;
        return [
            SELECT Id, Field, PermissionsEdit, PermissionsRead, ParentId, SObjectType,
                   Parent.Name, Parent.IsOwnedByProfile, Parent.Profile.Name
            FROM FieldPermissions
            WHERE SObjectType = :objectApiName
              AND Field = :fullFieldName
        ];
    }
}
