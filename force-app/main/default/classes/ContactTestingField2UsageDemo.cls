public with sharing class ContactTestingField2UsageDemo {
    public static List<Contact> findContactsWithTestingField2(Integer limitSize) {
        Integer safeLimit = limitSize == null || limitSize <= 0 ? 10 : Math.min(limitSize, 200);
        return [
            SELECT Id, Name, Testing_Field_2__c
            FROM Contact
            WHERE Testing_Field_2__c != null
            LIMIT :safeLimit
        ];
    }

    public static void stampTestingField2(Contact contactRecord, String value) {
        if (contactRecord == null) {
            return;
        }
        contactRecord.Testing_Field_2__c = String.isBlank(value)
            ? 'Metadata Copilot test value'
            : value;
    }
}
