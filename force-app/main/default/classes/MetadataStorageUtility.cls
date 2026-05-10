public with sharing class MetadataStorageUtility {
    public static Boolean isStorageLimitException(DmlException dmlError) {
        return dmlError != null &&
            dmlError.getMessage() != null &&
            dmlError.getMessage().contains('STORAGE_LIMIT_EXCEEDED');
    }

    public static Boolean containsStorageLimitError(List<String> errors) {
        if (errors == null) {
            return false;
        }

        for (String error : errors) {
            if (error != null && error.toLowerCase().contains('storage limit exceeded')) {
                return true;
            }
        }

        return false;
    }
}
